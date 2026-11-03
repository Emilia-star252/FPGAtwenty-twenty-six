// hmi.h -- 1024x600 power monitor HMI (Qt Widgets, linuxfb + our own evdev touch)
#ifndef HMI_H
#define HMI_H

#include <QWidget>
#include <QVector>
#include <QPoint>
#include <QTcpSocket>
#include <QTimer>
#include <QElapsedTimer>
#include "protocol.h"

QT_BEGIN_NAMESPACE
class QLabel;
class QPushButton;
QT_END_NAMESPACE

class TouchInput;

// ---------------------------------------------------------------------------
// realtime curve: voltage (green) + current (amber), auto-scaled
// ---------------------------------------------------------------------------
class CurveWidget : public QWidget
{
public:
    explicit CurveWidget(QWidget *parent = nullptr);
    void addSample(double v, double i);
    void clear();

protected:
    void paintEvent(QPaintEvent *) override;

private:
    static const int MAXPTS = 600;
    QVector<double> m_v, m_i;
};

// ---------------------------------------------------------------------------
// main window
// ---------------------------------------------------------------------------
class HmiWindow : public QWidget
{
    Q_OBJECT
public:
    explicit HmiWindow(const QString &host, quint16 port,
                       const QString &touchDev, QWidget *parent = nullptr);

public slots:
    void onPoll();
    void onHeartbeat();
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void scheduleReconnect();
    void onTap(const QPoint &p);
    void onNpuPoll();

private:
    enum Act {
        ACT_NONE = 0,
        ACT_V_UP, ACT_V_DN,
        ACT_I_UP, ACT_I_DN,
        ACT_APPLY, ACT_OUT_ON, ACT_OUT_OFF, ACT_CLEAR
    };

    void buildUi();
public:
    void setMode(const QString &mode);
private:
    void send(quint8 cmd, const QByteArray &payload = QByteArray());
    void applyStatus(const proto::Status &st);
    void setLed(QLabel *led, bool on, const QString &text);
    void logLine(const QString &s);
    void doAction(int act);
    void refreshSetpointLabels();
    void addHot(QWidget *w, int act);

    // link
    QTcpSocket *m_sock = nullptr;
    proto::Parser m_parser;
    quint8 m_seq = 0;
    QString m_host;
    quint16 m_port;
    bool m_online = false;

    // touch
    TouchInput *m_touch = nullptr;

    // timers
    QTimer *m_pollTimer = nullptr;
    QTimer *m_hbTimer   = nullptr;
    QTimer *m_clkTimer  = nullptr;
    QTimer *m_retry     = nullptr;
    QTimer *m_npuTimer  = nullptr;

    // hot zones (widgets that react to a tap)
    struct Hot { QWidget *w; int act; };
    QVector<Hot> m_hot;

    // widgets
    QLabel *m_lblV = nullptr, *m_lblI = nullptr, *m_lblDuty = nullptr;
    QLabel *m_lblGiven = nullptr;
    QLabel *m_lblNpuStatus = nullptr, *m_lblNpuCode = nullptr;
    QLabel *m_lblSetV = nullptr;
    QLabel *m_lblFault = nullptr;
    QLabel *m_ledRun = nullptr, *m_ledOut = nullptr, *m_ledHost = nullptr;
    QLabel *m_ledOvp = nullptr, *m_ledOcp = nullptr, *m_ledOtp = nullptr;
    QLabel *m_ledPlAct = nullptr, *m_ledPlPll = nullptr, *m_ledPlAdc = nullptr;
    QLabel *m_lblClock = nullptr, *m_lblLink = nullptr, *m_lblMode = nullptr;
    QLabel *m_lblLog = nullptr;
    QLabel *m_lblStats = nullptr;
    QPushButton *m_btnVUp = nullptr, *m_btnVDn = nullptr;
    QPushButton *m_btnApply = nullptr, *m_btnOn = nullptr;
    QPushButton *m_btnOff = nullptr, *m_btnClr = nullptr;
    CurveWidget *m_curve = nullptr;

    double m_setV = 12.0;
    double m_setI = 5.0;
    proto::Status m_last;
    bool m_haveStatus = false;
};

#endif // HMI_H
