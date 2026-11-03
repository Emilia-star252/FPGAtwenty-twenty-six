#include "usb_camera.hpp"
#include "logger_forward.hpp"
#include "stream_input.hpp"

struct usb_camera_t::usb_camera_impl {
    usb_camera_t *P;
    usb_camera_impl(usb_camera_t *P_)
        : P(P_) {}

    stream_input stream_input_ins;
    jpu_decoder_gift gift;
    jpu_cma_buffer buf; // 输出buf，从外面导入
};

usb_camera_t::usb_camera_t()
    : impl(new usb_camera_impl(this)) {
}
usb_camera_t::usb_camera_t(int w, int h)
    : impl(new usb_camera_impl(this))
    , m_width(w)
    , m_height(h) {
    m_widthPad16 = (w + 15) / 16 * 16;
    m_heightPad16 = (h + 15) / 16 * 16;
}
usb_camera_t::~usb_camera_t() {
    impl.reset();
    open_err_code = -1;
}

int usb_camera_t::init(const char *dev_path) {
    impl->stream_input_ins.open(dev_path, m_width, m_height);
    if (impl->stream_input_ins.is_open()) {
        // LOG_INFO("stream_input open success");
        return 0;
    } else {
        LOG_ERROR("{} open failed", dev_path);
        return -1;
    }
}
void usb_camera_t::SubmitAndStart(uint64_t dma_rx_buf, void *rx_buf) {
    if (!impl->stream_input_ins.is_open() || impl->stream_input_ins.is_eof()) {
        error_code = -1;
        return;
    }
    cma_buffer_t bf;
    bf.phys_addr = dma_rx_buf;
    bf.size = buffer_size();
    impl->buf.import(bf);
    // 判断是否有bit
    if (impl->gift.get_bitfeed().cma.size == 0) {
        impl->gift.emplace_jpeg_bits_from(impl->stream_input_ins); // 导入bit
    }
    while (!(impl->gift.decode_frame_to(impl->buf))) {
        if (impl->stream_input_ins.is_eof()) {
            error_code = -1;
            return;
        }
        impl->gift.emplace_jpeg_bits_from(impl->stream_input_ins);
    }
    error_code = 0;
}

std::vector<uint8_t> usb_camera_t::GetJpegStream() {
    std::vector<uint8_t> ret(impl->gift.get_bitfeed().rdptr);
    memcpy(ret.data(), impl->gift.get_bitfeed().cma.virt_addr, impl->gift.get_bitfeed().rdptr);
    return ret;
}

void usb_camera_t::SaveJpegStream(std::ostream &fs) {
    fs.write(reinterpret_cast<const char *>(impl->gift.get_bitfeed().cma.virt_addr), impl->gift.get_bitfeed().rdptr);
}

bool usb_camera_t::is_dev_video() const {
    return impl->stream_input_ins.is_dev_video();
}
