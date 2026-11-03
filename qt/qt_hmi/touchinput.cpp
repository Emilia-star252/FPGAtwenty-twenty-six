// touchinput.cpp -- minimal evdev touch reader (no Qt input plugins involved)
#include "touchinput.h"

#include <QSocketNotifier>
#include <QDebug>

#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <linux/input.h>
#include <sys/ioctl.h>

static int absMax(int fd, int axis, int *minv, int *maxv)
{
    struct input_absinfo ai;
    memset(&ai, 0, sizeof(ai));
    if (ioctl(fd, EVIOCGABS(axis), &ai) < 0) return -1;
    *minv = ai.minimum;
    *maxv = ai.maximum;
    return 0;
}

TouchInput::TouchInput(const QString &dev, QSize screen, QObject *parent)
    : QObject(parent), m_screen(screen)
{
    m_fd = ::open(dev.toLocal8Bit().constData(), O_RDONLY | O_NONBLOCK);
    if (m_fd < 0) {
        qWarning("touch: cannot open %s: %s", qPrintable(dev), strerror(errno));
        return;
    }

    int mn = 0, mx = 0;
    if (absMax(m_fd, ABS_MT_POSITION_X, &mn, &mx) == 0 && mx > mn) {
        m_xMin = mn; m_xMax = mx; m_haveX = true;
    } else if (absMax(m_fd, ABS_X, &mn, &mx) == 0 && mx > mn) {
        m_xMin = mn; m_xMax = mx; m_haveX = true;
    }
    if (absMax(m_fd, ABS_MT_POSITION_Y, &mn, &mx) == 0 && mx > mn) {
        m_yMin = mn; m_yMax = mx; m_haveY = true;
    } else if (absMax(m_fd, ABS_Y, &mn, &mx) == 0 && mx > mn) {
        m_yMin = mn; m_yMax = mx; m_haveY = true;
    }
    qInfo("touch: %s opened, x=[%d..%d] y=[%d..%d] screen=%dx%d",
          qPrintable(dev), m_xMin, m_xMax, m_yMin, m_yMax,
          m_screen.width(), m_screen.height());

    m_notify = new QSocketNotifier(m_fd, QSocketNotifier::Read, this);
    connect(m_notify, &QSocketNotifier::activated, this, &TouchInput::onReadable);
}

TouchInput::~TouchInput()
{
    if (m_fd >= 0) ::close(m_fd);
}

QPoint TouchInput::scale() const
{
    int x = m_rawX, y = m_rawY;
    if (m_haveX && m_xMax > m_xMin)
        x = (m_rawX - m_xMin) * m_screen.width() / (m_xMax - m_xMin);
    if (m_haveY && m_yMax > m_yMin)
        y = (m_rawY - m_yMin) * m_screen.height() / (m_yMax - m_yMin);
    // clamp
    x = qBound(0, x, m_screen.width()  - 1);
    y = qBound(0, y, m_screen.height() - 1);
    return QPoint(x, y);
}

void TouchInput::onReadable()
{
    struct input_event ev[64];
    for (;;) {
        const ssize_t n = ::read(m_fd, ev, sizeof(ev));
        if (n <= 0) break;
        const int cnt = int(n / sizeof(struct input_event));
        for (int i = 0; i < cnt; ++i) {
            const struct input_event &e = ev[i];

            if (e.type == EV_ABS) {
                switch (e.code) {
                case ABS_MT_POSITION_X:
                case ABS_X:
                    m_rawX = e.value;
                    if (!m_seenBtnTouch) m_pendingApp = true;
                    break;
                case ABS_MT_POSITION_Y:
                case ABS_Y:
                    m_rawY = e.value;
                    if (!m_seenBtnTouch) m_pendingApp = true;
                    break;
                case ABS_MT_TRACKING_ID:
                    if (e.value < 0) { m_down = false; }
                    else             { m_down = true; m_pendingApp = true; }
                    break;
                default: break;
                }
            } else if (e.type == EV_KEY) {
                if (e.code == BTN_TOUCH || e.code == BTN_LEFT) {
                    m_seenBtnTouch = true;
                    if (e.value == 1) {
                        m_down = true;
                    } else if (e.value == 0) {
                        m_down = false;
                        emit tapped(scale());          // tap = press + release
                    }
                }
            } else if (e.type == EV_SYN && e.code == SYN_REPORT) {
                // panels that report only ABS (no BTN_TOUCH): treat a SYN as a tap
                if (!m_seenBtnTouch && m_pendingApp && !m_down) {
                    m_pendingApp = false;
                    emit tapped(scale());
                }
            }
        }
    }
}
