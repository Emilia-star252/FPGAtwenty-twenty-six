/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

/***************************************************************
 *  @file This is mipicam driver using cdev driver.
 *  Last modified by
 *       30-01-2024   ritao.xiao
 ****************************************************************/

#include "mipicam_module.h"
#include <linux/cdev.h>
#include <linux/io.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/of_irq.h>
#include <linux/platform_device.h>
#include <linux/types.h>
#include <linux/uaccess.h>
#include <linux/uio_driver.h>
#include <linux/kernel.h>
#include <linux/init.h>

#define CDEV_DEV_NAME "mipicam"

#define CAMERA_BASE_ADDR 0x000
#define CAMERA_START 0x004
#define CAMERA_CLEAR_INTR 0x008

static uint32_t CAMERA_CLEAR_INTR_REG = CAMERA_CLEAR_INTR;

static mipicam_drv_buffer_t s_mipicam_register;
#define ReadRegister(addr) \
	(*(volatile unsigned int *)(s_mipicam_register.virt_addr + addr))
#define WriteRegister(addr, val)                                             \
	((*(volatile unsigned int *)(s_mipicam_register.virt_addr + addr)) = \
		 ((unsigned int)val))

static uint32_t s_intr_flag;
static uint32_t s_work_status;
static wait_queue_head_t s_intr_wait_q;
static int mipicam_irq_num;

static int s_major;
static struct class *s_dev_class;
static struct device *s_devp;
static struct device *mipicam_devp;
static struct cdev s_cdev;

static int s_is_open;

static irqreturn_t my_mipicam_interrupt(int irq, void *dev_id)
{
	s_intr_flag = 1;
	WriteRegister(CAMERA_CLEAR_INTR_REG, 0x01U);
	wake_up_interruptible(&s_intr_wait_q);
	return IRQ_RETVAL(IRQ_HANDLED);
}

static int mipicam_open(struct inode *inode, struct file *filp)
{
	s_intr_flag = 0;

	if (s_is_open == 0) {
		s_is_open = 1;
		return 0;
	}

	dev_err(mipicam_devp, "mipicam is obtained by another instance!\n");
	return -1;
}

static int mipicam_release(struct inode *inode, struct file *filp)
{
	if (s_is_open == 0) {
		dev_err(mipicam_devp, "mipicam is not opened!\n");
		return -1;
	}
	s_is_open = 0;
	return 0;
}

static ssize_t mipicam_read(struct file *filp, char __user *buf, size_t len,
			    loff_t *ppos)
{
	dev_err(mipicam_devp, "Not supported\n");
	return -1;
}

static ssize_t mipicam_write(struct file *filp, const char __user *buf,
			     size_t len, loff_t *ppos)
{
	dev_err(mipicam_devp, "Not supported\n");
	return -1;
}

static long mipicam_ioctl(struct file *filp, u_int cmd, u_long arg)
{
	long ret = 0;
	mipicam_reg_info_t info;
	mipicam_rw_info_t rw;
	mipicam_intr_info_t intr;

	switch (cmd) {
	case MIPICAM_IOCTL_WAIT_INTERRUPT:
		// dev_info(mipicam_devp, "MIPICAM_IOCTL_WAIT_INTERRUPT\n");
		ret = copy_from_user(&intr, (void __user *)arg,
				     sizeof(mipicam_intr_info_t));
		if (ret != 0) {
			ret = -EFAULT;
			dev_err(mipicam_devp, "copy_from_user failed\n");
			break;
		}
		ret = wait_event_interruptible_timeout(
			s_intr_wait_q, s_intr_flag != 0,
			msecs_to_jiffies(intr.timeout));
		if (!ret) {
			dev_err(mipicam_devp, "mipicam intr timeout!\n");
			ret = -ETIME;
			break;
		}
		if (signal_pending(current)) {
			ret = -ERESTARTSYS;
			dev_warn(mipicam_devp, "[MIPICAM] ERESTARTSYS\n");
			break;
		}
		// dev_info(mipicam_devp, "s_intr_flag = %x\n", s_intr_flag);
		intr.intr_flag = s_intr_flag;
		intr.work_status = s_work_status;
		s_intr_flag = 0;
		ret = copy_to_user((void __user *)arg, &intr,
				   sizeof(mipicam_intr_info_t));
		if (ret != 0) {
			dev_err(mipicam_devp, "copy_to_user failed\n");
			ret = -EFAULT;
			break;
		}
		break;
	case MIPICAM_IOCTL_GET_REGISTER_INFO:
		info.addr = s_mipicam_register.phys_addr;
		info.size = s_mipicam_register.size;
		ret = copy_to_user((void __user *)arg, &info,
				   sizeof(mipicam_reg_info_t));
		if (ret != 0) {
			dev_err(mipicam_devp, "copy_to_user failed\n");
			ret = -EFAULT;
			break;
		}
		break;
	case MIPICAM_IOCTL_WRITE_REG:
		ret = copy_from_user(&rw, (void __user *)arg,
				     sizeof(mipicam_rw_info_t));
		if (ret != 0) {
			dev_err(mipicam_devp, "copy_from_user failed\n");
			ret = -EFAULT;
			break;
		}
		WriteRegister(rw.addr, rw.data);
		break;
	case MIPICAM_IOCTL_READ_REG:
		ret = copy_from_user(&rw, (void __user *)arg,
				     sizeof(mipicam_rw_info_t));
		if (ret != 0) {
			dev_err(mipicam_devp, "copy_from_user failed\n");
			ret = -EFAULT;
			break;
		}
		rw.data = ReadRegister(rw.addr);
		ret = copy_to_user((void __user *)arg, &rw,
				   sizeof(mipicam_rw_info_t));
		if (ret != 0) {
			dev_err(mipicam_devp, "copy_to_user failed\n");
			ret = -EFAULT;
			break;
		}
		break;
	case MIPICAM_IOCTL_CLEAR_IRQ_REG_OFFSET:
		CAMERA_CLEAR_INTR_REG = arg;
		break;
	default:
		dev_err(mipicam_devp, "No supported cmd!\n");
		break;
	}
	return ret;
}

static int mipicam_mmap(struct file *fp, struct vm_area_struct *vm)
{
	if (vm->vm_pgoff != (s_mipicam_register.phys_addr >> 12U)) {
		dev_err(mipicam_devp, "No supported\n");
		return -EFAULT;
	}
	vm->vm_flags |= VM_IO | VM_DONTEXPAND | VM_DONTDUMP;
	vm->vm_page_prot = pgprot_noncached(vm->vm_page_prot);
	dev_info(mipicam_devp, "map_to_register: phys_addr: %lx\n",
		 s_mipicam_register.phys_addr);
	return remap_pfn_range(vm, vm->vm_start, vm->vm_pgoff,
			       vm->vm_end - vm->vm_start, vm->vm_page_prot) ?
		       -EAGAIN :
		       0;
}

const struct file_operations mipicam_fops = {
	.owner = THIS_MODULE,
	.open = mipicam_open,
	.release = mipicam_release,
	.read = mipicam_read,
	.write = mipicam_write,
	.unlocked_ioctl = mipicam_ioctl,
	.mmap = mipicam_mmap,
};

static int drv_mipicam_probe(struct platform_device *pdev);
static int drv_mipicam_remove(struct platform_device *pdev);
static const struct of_device_id mipicam_match_table[] = {
	{ .compatible = "anlogic,mipicam" },
};

static struct platform_driver
	mipicam_driver = { .probe = drv_mipicam_probe,
			   .remove = drv_mipicam_remove,
			   .driver = {
				   .name = "mipicam",
				   .owner = THIS_MODULE,
				   .of_match_table = mipicam_match_table,
			   } };

static int drv_mipicam_probe(struct platform_device *pdev)
{
	dev_info(&(pdev->dev), "%s( %p)\n", __func__, pdev);
	mipicam_devp = &(pdev->dev);

	mipicam_irq_num = platform_get_irq(pdev, 0);
	if (mipicam_irq_num < 0) {
		dev_err(mipicam_devp,
			"get irq resource failed in mipicam device\n");
		return -EINVAL;
	}
	dev_info(mipicam_devp, "find irq num: %d\n", mipicam_irq_num);

	struct resource *mem_src_p =
		platform_get_resource(pdev, IORESOURCE_MEM, 0);

	if (mem_src_p == NULL) {
		dev_err(mipicam_devp,
			"get mem resource failed in mipicam device\n");
		return -EINVAL;
	}

	s_mipicam_register.virt_addr =
		devm_ioremap_resource(&pdev->dev, mem_src_p);
	dev_info(mipicam_devp, "devm_ioremap_resource return %p\n",
		 s_mipicam_register.virt_addr);

	s_mipicam_register.phys_addr = mem_src_p->start;
	dev_info(mipicam_devp, "mem start addr: %lx\n",
		 s_mipicam_register.phys_addr);

	s_mipicam_register.size = (mem_src_p->end - mem_src_p->start + 1);
	dev_info(mipicam_devp, "mem size: %d\n", s_mipicam_register.size);

	/* get the major number of the character device */
	if ((alloc_chrdev_region(&s_major, 0, 1, CDEV_DEV_NAME)) < 0) {
		dev_err(mipicam_devp, "could not allocate major number\n");
		return -EBUSY;
	}

	/* initialize the device structure and register the device with the kernel */
	cdev_init(&s_cdev, &mipicam_fops);
	s_cdev.owner = THIS_MODULE;
	if ((cdev_add(&s_cdev, s_major, 1)) < 0) {
		dev_err(mipicam_devp, "could not allocate chrdev\n");
		unregister_chrdev_region(s_major, 1);
		return -EBUSY;
	}

	// request handler
	int err = request_irq(mipicam_irq_num, my_mipicam_interrupt,
			      IRQF_TRIGGER_HIGH, "MIPICAM_IRQ", (void *)NULL);
	if (err) {
		dev_err(mipicam_devp, "fail to register interrupt handler\n");
		cdev_del(&s_cdev);
		unregister_chrdev_region(s_major, 1);
		return err;
	}

	// create device class
	s_dev_class = class_create(THIS_MODULE, CDEV_DEV_NAME);
	if (IS_ERR(s_dev_class)) {
		dev_err(mipicam_devp, "fail to create device class\n");
		err = PTR_ERR(s_dev_class);
		free_irq(mipicam_irq_num, (void *)NULL);
		cdev_del(&s_cdev);
		unregister_chrdev_region(s_major, 1);
		return err;
	}
	// create device
	s_devp = device_create(s_dev_class, NULL, s_major, NULL, "%s",
			       CDEV_DEV_NAME);
	if (IS_ERR(s_devp)) {
		dev_err(mipicam_devp, "fail to create device\n");
		err = PTR_ERR(s_devp);
		class_destroy(s_dev_class);
		free_irq(mipicam_irq_num, (void *)NULL);
		cdev_del(&s_cdev);
		unregister_chrdev_region(s_major, 1);
		return err;
	}
	return 0;
}

static int drv_mipicam_remove(struct platform_device *pdev)
{
	dev_info(mipicam_devp, "%s( %p)\n", __func__, pdev);
	device_destroy(s_dev_class, s_major);
	class_destroy(s_dev_class);
	free_irq(mipicam_irq_num, (void *)NULL);
	cdev_del(&s_cdev);
	unregister_chrdev_region(s_major, 1);

	if (s_mipicam_register.virt_addr && 0) // auto release by linux
		iounmap(s_mipicam_register.virt_addr);

	return 0;
}

static int __init mipicam_init(void)
{
	init_waitqueue_head(&s_intr_wait_q);
	return platform_driver_register(&mipicam_driver);
}

static void __exit mipicam_exit(void)
{
	platform_driver_unregister(&mipicam_driver);
}

module_init(mipicam_init);
module_exit(mipicam_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("mipicam driver");
