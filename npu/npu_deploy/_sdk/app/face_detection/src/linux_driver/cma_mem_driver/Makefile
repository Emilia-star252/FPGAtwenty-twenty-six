CROSS_PREFIX ?= /data/home/szwang/workspace/embedded_linux_DE/embedded-linux/aarch64-anlogic-11.3/bin/aarch64-anlogic-linux-gnu-
CC := $(CROSS_PREFIX)gcc
LD := $(CROSS_PREFIX)ld

#dir of linux kernel code
KERNELDIR ?= /data/home/szwang/workspace/embedded_linux_DE/embedded-linux/linux-5.10.142

CURRENT_PATH := `pwd`
ARCH := arm64

#name of target module
obj-m := cma_mem.o

build: kernel_modules

kernel_modules:
	$(MAKE) -C $(KERNELDIR) M=$(CURRENT_PATH) modules ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_PREFIX)

clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURRENT_PATH) clean
