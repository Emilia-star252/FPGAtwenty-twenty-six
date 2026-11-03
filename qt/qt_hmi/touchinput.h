// touchinput.h -- read /dev/input/eventX directly (avoids Qt's buggy evdevtouch
// plugin on Qt 5.13 + linuxfb). Emits a tap (press+release) in screen pixels.
#ifndef TOUCHINPUT_H
#define TOUCHINPUT_H

#include <QObject>
#include <QPoint>
#include <QSize>

class QSocketNotifier;

class TouchInput : public QObject
{
    Q_OBJECT
public:
    explicit TouchInput(const QString &dev, QSize screen, QObject *parent = nullptr);
    ~TouchInput() override;

    bool isOpen() const { return m_fd >= 0; }

signals:
    void tapped(const QPoint &pos);       // screen coordinates

private slots:
    void onReadable();

private:
    int    m_fd = -1;
    QSocketNotifier *m_notify = nullptr;
    QSize  m_screen;

    // raw axis ranges read from the device
    int m_xMin = 0, m_xMax = 0, m_yMin = 0, m_yMax = 0;
    bool m_haveX = false, m_haveY = false;

    // current raw position
    int  m_rawX = 0, m_rawY = 0;
    bool m_down = false;
    bool m_seenBtnTouch = false;
    bool m_pendingApp = false;

    QPoint scale() const;
};

#endif // TOUCHINPUT_H
