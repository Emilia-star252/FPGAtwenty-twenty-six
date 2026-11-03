// hmi.cpp -- 1024x600 power monitor HMI (Qt Widgets on linuxfb, own evdev touch)
#include "hmi.h"
#include "touchinput.h"

#include <QPainter>
#include <QPainterPath>
#include <QLabel>
#include <QPushButton>
#include <QGridLayout>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QFrame>
#include <QDateTime>
#include <QHostAddress>
#include <QtMath>
#include <QFile>
#include <cstdio>
#include <cstring>

// ---------------------------------------------------------------------------
// palette
// ---------------------------------------------------------------------------
static const QColor C_BG      ("#0E1116");
static const QColor C_PANEL   ("#161B22");
static const QColor C_TEXT    ("#E6EDF3");
static const QColor C_DIM     ("#7D8794");
static const QColor C_ACCENT  ("#00E5A0");
static const QColor C_AMBER   ("#FFB020");
static const QColor C_RED     ("#FF4D4F");
static const QColor C_BLUE    ("#1F6FEB");

static QLabel *mkLabel(const QString &text, int px, const QColor &c, bool bold = false)
{
    QLabel *l = new QLabel(text);
    QFont f = l->font();
    f.setPixelSize(px);
    f.setBold(bold);
    l->setFont(f);
    l->setStyleSheet(QString("color:%1; background:transparent;").arg(c.name()));
    return l;
}

static QFrame *mkPanel(QWidget *parent)
{
    QFrame *f = new QFrame(parent);
    f->setStyleSheet(QString("QFrame{background:%1; border:1px solid #232A33; border-radius:8px;}")
                     .arg(C_PANEL.name()));
    return f;
}

static QPushButton *mkBtn(const QString &text, int px, const QString &css)
{
    QPushButton *b = new QPushButton(text);
    b->setStyleSheet(css);
    QFont f = b->font();
    f.setPixelSize(px);
    f.setBold(true);
    b->setFont(f);
    return b;
}

// ---------------------------------------------------------------------------
// CurveWidget
// ---------------------------------------------------------------------------
CurveWidget::CurveWidget(QWidget *parent) : QWidget(parent)
{
    setMinimumHeight(170);
    setAttribute(Qt::WA_OpaquePaintEvent, true);
}

void CurveWidget::addSample(double v, double i)
{
    m_v.append(v);
    m_i.append(i);
    while (m_v.size() > MAXPTS) m_v.remove(0);
    while (m_i.size() > MAXPTS) m_i.remove(0);
    update();
}

void CurveWidget::clear()
{
    m_v.clear();
    m_i.clear();
    update();
}

void CurveWidget::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.fillRect(rect(), C_PANEL);
    p.setPen(QPen(QColor("#232A33"), 1));
    p.drawRect(rect().adjusted(0, 0, -1, -1));

    const QRectF r = rect().adjusted(54, 14, -14, -24);

    p.setPen(QPen(QColor("#20262E"), 1, Qt::DashLine));
    for (int k = 0; k <= 4; ++k) {
        const double y = r.top() + r.height() * k / 4.0;
        p.drawLine(QPointF(r.left(), y), QPointF(r.right(), y));
    }
    for (int k = 0; k <= 6; ++k) {
        const double x = r.left() + r.width() * k / 6.0;
        p.drawLine(QPointF(x, r.top()), QPointF(x, r.bottom()));
    }

    auto vmax = [](const QVector<double> &a, double floorv) {
        double m = floorv;
        for (double x : a) if (x > m) m = x;
        return m * 1.15;
    };
    const double vV = vmax(m_v, 5.0);
    const double vI = vmax(m_i, 1.0);

    p.setPen(C_DIM);
    QFont f = font(); f.setPixelSize(12); p.setFont(f);
    p.drawText(QRectF(2, r.top() - 6, 48, 14), Qt::AlignRight, QString::number(vV, 'f', 1));
    p.drawText(QRectF(2, r.bottom() - 8, 48, 14), Qt::AlignRight, "0");
    p.drawText(QRectF(r.left(), r.bottom() + 6, 300, 16), Qt::AlignLeft,
               QStringLiteral("电压 V（绿） / 电流 A（黄）"));

    auto drawSeries = [&](const QVector<double> &a, double mx, const QColor &c) {
        if (a.size() < 2) return;
        QPainterPath path;
        for (int k = 0; k < a.size(); ++k) {
            const double x = r.left() + r.width() * k / double(MAXPTS - 1);
            const double y = r.bottom() - r.height() * qBound(0.0, a[k] / mx, 1.0);
            if (k == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        p.setPen(QPen(c, 2));
        p.drawPath(path);
    };
    drawSeries(m_i, vI, C_AMBER);
    drawSeries(m_v, vV, C_ACCENT);
}

// ---------------------------------------------------------------------------
// HmiWindow
// ---------------------------------------------------------------------------
HmiWindow::HmiWindow(const QString &host, quint16 port,
                     const QString &touchDev, QWidget *parent)
    : QWidget(parent), m_host(host), m_port(port)
{
    buildUi();

    // ---- network ----
    m_sock = new QTcpSocket(this);
    connect(m_sock, &QTcpSocket::connected,    this, &HmiWindow::onConnected);
    connect(m_sock, &QTcpSocket::disconnected, this, &HmiWindow::onDisconnected);
    connect(m_sock, &QTcpSocket::readyRead,    this, &HmiWindow::onReadyRead);
#if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
    connect(m_sock, &QAbstractSocket::errorOccurred, this,
            [this](QAbstractSocket::SocketError) { scheduleReconnect(); });
#else
    connect(m_sock, QOverload<QAbstractSocket::SocketError>::of(&QAbstractSocket::error),
            this, [this](QAbstractSocket::SocketError) { scheduleReconnect(); });
#endif

    m_retry = new QTimer(this);
    m_retry->setSingleShot(true);
    connect(m_retry, &QTimer::timeout, this, [this] {
        if (m_sock->state() == QAbstractSocket::UnconnectedState)
            m_sock->connectToHost(m_host, m_port);
    });
    m_sock->connectToHost(host, port);

    m_pollTimer = new QTimer(this);
    connect(m_pollTimer, &QTimer::timeout, this, &HmiWindow::onPoll);
    m_pollTimer->start(100);                    // 10 Hz

    m_hbTimer = new QTimer(this);
    connect(m_hbTimer, &QTimer::timeout, this, &HmiWindow::onHeartbeat);
    m_hbTimer->start(1000);

    m_clkTimer = new QTimer(this);
    connect(m_clkTimer, &QTimer::timeout, this, [this] {
        m_lblClock->setText(QDateTime::currentDateTime().toString("HH:mm:ss"));
    });
    m_clkTimer->start(500);
    m_lblClock->setText(QDateTime::currentDateTime().toString("HH:mm:ss"));

    // ---- touch (our own reader; no Qt input plugins) ----
    if (!touchDev.isEmpty()) {
        m_touch = new TouchInput(touchDev, QSize(1024, 600), this);
        connect(m_touch, &TouchInput::tapped, this, &HmiWindow::onTap);
    }

    m_npuTimer = new QTimer(this);
    connect(m_npuTimer, &QTimer::timeout, this, &HmiWindow::onNpuPoll);
    m_npuTimer->start(500);
    onNpuPoll();

    logLine(QStringLiteral("HMI 启动，目标 %1:%2").arg(m_host).arg(m_port));
}

void HmiWindow::addHot(QWidget *w, int act)
{
    if (!w) return;
    Hot h; h.w = w; h.act = act;
    m_hot.append(h);
}

void HmiWindow::buildUi()
{
    setStyleSheet(QString("background:%1;").arg(C_BG.name()));
    setFixedSize(1024, 600);

    const QString cssBlue =
        "QPushButton{background:#1F6FEB;color:#fff;border:none;border-radius:6px;padding:6px;}"
        "QPushButton:pressed{background:#1550B0;}";
    const QString cssGreen =
        "QPushButton{background:#238636;color:#fff;border:none;border-radius:6px;padding:6px;}"
        "QPushButton:pressed{background:#1A6329;}";
    const QString cssRed =
        "QPushButton{background:#8B2E2E;color:#fff;border:none;border-radius:6px;padding:6px;}"
        "QPushButton:pressed{background:#6B2222;}";
    const QString cssAmber =
        "QPushButton{background:#6E5A1E;color:#fff;border:none;border-radius:6px;padding:6px;}"
        "QPushButton:pressed{background:#544514;}";
    const QString cssGray =
        "QPushButton{background:#2A323C;color:#E6EDF3;border:none;border-radius:6px;}"
        "QPushButton:pressed{background:#3A4450;}";

    QVBoxLayout *root = new QVBoxLayout(this);
    root->setContentsMargins(10, 8, 10, 8);
    root->setSpacing(8);

    // ---- header ----
    QHBoxLayout *hdr = new QHBoxLayout;
    hdr->addWidget(mkLabel(QStringLiteral("智能电源状态监测与故障诊断系统"), 24, C_TEXT, true));
    hdr->addStretch();
    m_lblLink  = mkLabel(QStringLiteral("● 未连接"), 18, C_RED, true);
    m_lblClock = mkLabel(QStringLiteral("--:--:--"), 18, C_DIM);
    hdr->addSpacing(14);
    hdr->addWidget(m_lblLink);
    hdr->addSpacing(18);
    hdr->addWidget(m_lblClock);
    root->addLayout(hdr);

    // ---- body ----
    QHBoxLayout *body = new QHBoxLayout;
    body->setSpacing(10);

    // left: live values
    QFrame *left = mkPanel(this);
    QGridLayout *gl = new QGridLayout(left);
    gl->setContentsMargins(18, 10, 18, 8);
    gl->setHorizontalSpacing(12);
    gl->setVerticalSpacing(2);

    gl->addWidget(mkLabel(QStringLiteral("输出电压"), 15, C_DIM), 0, 0);
    m_lblV = mkLabel(QStringLiteral("0.00"), 50, C_ACCENT, true);
    gl->addWidget(m_lblV, 1, 0);
    gl->addWidget(mkLabel(QStringLiteral("V"), 22, C_DIM), 1, 1, Qt::AlignBottom);

    gl->addWidget(mkLabel(QStringLiteral("输出电流"), 15, C_DIM), 2, 0);
    m_lblI = mkLabel(QStringLiteral("0.00"), 50, C_AMBER, true);
    gl->addWidget(m_lblI, 3, 0);
    gl->addWidget(mkLabel(QStringLiteral("A"), 22, C_DIM), 3, 1, Qt::AlignBottom);

    gl->addWidget(mkLabel(QStringLiteral("占空比"), 15, C_DIM), 4, 0);
    m_lblDuty = mkLabel(QStringLiteral("0.0 %"), 32, C_TEXT, true);
    gl->addWidget(m_lblDuty, 5, 0);

    m_lblGiven = mkLabel(QStringLiteral("给定 0.00 V / 0.00 A"), 15, C_DIM);
    gl->addWidget(m_lblGiven, 6, 0, 1, 2);

    m_lblStats = mkLabel(QStringLiteral("收帧 0  CRC错 0"), 12, C_DIM);
    gl->addWidget(m_lblStats, 7, 0, 1, 2);

    // right: setpoints + actions
    QFrame *right = mkPanel(this);
    QGridLayout *gr = new QGridLayout(right);
    gr->setContentsMargins(16, 10, 16, 10);
    gr->setHorizontalSpacing(8);
    gr->setVerticalSpacing(6);

    gr->addWidget(mkLabel(QStringLiteral("电压给定 (V)"), 15, C_DIM), 0, 0);
    m_btnVDn = mkBtn(QStringLiteral("-"), 22, cssGray);
    m_btnVDn->setFixedSize(48, 38);
    gr->addWidget(m_btnVDn, 0, 1);
    m_lblSetV = mkLabel(QStringLiteral("12.00"), 24, C_TEXT, true);
    m_lblSetV->setAlignment(Qt::AlignCenter);
    m_lblSetV->setMinimumWidth(96);
    gr->addWidget(m_lblSetV, 0, 2);
    m_btnVUp = mkBtn(QStringLiteral("+"), 22, cssGray);
    m_btnVUp->setFixedSize(48, 38);
    gr->addWidget(m_btnVUp, 0, 3);

    /* --- NPU recognition panel (left of the apply button) --- */
    QFrame *npu = new QFrame(right);
    npu->setStyleSheet("QFrame{background:#0F151C; border:1px solid #25303B; border-radius:6px;}");
    QVBoxLayout *nv = new QVBoxLayout(npu);
    nv->setContentsMargins(10, 4, 10, 4);
    nv->setSpacing(0);
    nv->addWidget(mkLabel(QStringLiteral("NPU 识别"), 13, C_DIM));
    m_lblNpuStatus = mkLabel(QStringLiteral("● 无结果"), 20, C_DIM, true);
    nv->addWidget(m_lblNpuStatus);
    m_lblNpuCode = mkLabel(QStringLiteral("代码 -"), 12, C_DIM);
    nv->addWidget(m_lblNpuCode);
    gr->addWidget(npu, 1, 0, 1, 2);

    m_btnApply = mkBtn(QStringLiteral("下发给定"), 18, cssBlue);
    m_btnApply->setFixedHeight(64);
    gr->addWidget(m_btnApply, 1, 2, 1, 2);

    m_btnOn  = mkBtn(QStringLiteral("输出开"), 18, cssGreen);
    m_btnOff = mkBtn(QStringLiteral("输出关"), 18, cssRed);
    m_btnClr = mkBtn(QStringLiteral("清故障"), 18, cssAmber);
    m_btnOn->setFixedHeight(46);
    m_btnOff->setFixedHeight(46);
    m_btnClr->setFixedHeight(46);
    gr->addWidget(m_btnOn, 2, 0, 1, 2);
    gr->addWidget(m_btnOff, 2, 2);
    gr->addWidget(m_btnClr, 2, 3);

    // LEDs
    QGridLayout *leds = new QGridLayout;
    leds->setHorizontalSpacing(8);
    leds->setVerticalSpacing(2);
    m_ledRun   = mkLabel(QStringLiteral("● 运行"),   15, C_DIM, true);
    m_ledOut   = mkLabel(QStringLiteral("● 输出"),   15, C_DIM, true);
    m_ledHost  = mkLabel(QStringLiteral("● 上位机"), 15, C_DIM, true);
    m_ledOvp   = mkLabel(QStringLiteral("● 过压"),   15, C_DIM, true);
    m_ledOcp   = mkLabel(QStringLiteral("● 过流"),   15, C_DIM, true);
    m_ledOtp   = mkLabel(QStringLiteral("● 过温"),   15, C_DIM, true);
    m_ledPlAct = mkLabel(QStringLiteral("● PWM"),    15, C_DIM, true);
    m_ledPlPll = mkLabel(QStringLiteral("● PLL"),    15, C_DIM, true);
    m_ledPlAdc = mkLabel(QStringLiteral("● ADC"),    15, C_DIM, true);
    QLabel *all[9] = {m_ledRun, m_ledOut, m_ledHost, m_ledOvp, m_ledOcp,
                      m_ledOtp, m_ledPlAct, m_ledPlPll, m_ledPlAdc};
    for (int k = 0; k < 9; ++k) leds->addWidget(all[k], k / 3, k % 3);
    gr->addLayout(leds, 3, 0, 1, 4);

    m_lblFault = mkLabel(QStringLiteral("故障：无"), 17, C_ACCENT, true);
    gr->addWidget(m_lblFault, 4, 0, 1, 4);

    body->addWidget(left, 50);
    body->addWidget(right, 50);
    root->addLayout(body, 1);

    // ---- curve ----
    m_curve = new CurveWidget(this);
    root->addWidget(m_curve, 1);

    // ---- log ----
    m_lblLog = mkLabel(QStringLiteral("就绪"), 14, C_DIM);
    root->addWidget(m_lblLog);

    // tap targets
    addHot(m_btnVUp,   ACT_V_UP);
    addHot(m_btnVDn,   ACT_V_DN);
    addHot(m_btnApply, ACT_APPLY);
    addHot(m_btnOn,    ACT_OUT_ON);
    addHot(m_btnOff,   ACT_OUT_OFF);
    addHot(m_btnClr,   ACT_CLEAR);

    refreshSetpointLabels();
}

void HmiWindow::refreshSetpointLabels()
{
    if (m_lblSetV) m_lblSetV->setText(QString::number(m_setV, 'f', 2));
}

void HmiWindow::setLed(QLabel *led, bool on, const QString &text)
{
    led->setText(QStringLiteral("● ") + text);
    led->setStyleSheet(QString("color:%1; background:transparent;")
                       .arg(on ? C_ACCENT.name() : C_DIM.name()));
}

void HmiWindow::logLine(const QString &s)
{
    m_lblLog->setText(QStringLiteral("[%1] %2")
                      .arg(QDateTime::currentDateTime().toString("HH:mm:ss"), s));
}

void HmiWindow::send(quint8 cmd, const QByteArray &payload)
{
    if (!m_sock || m_sock->state() != QAbstractSocket::ConnectedState) {
        logLine(QStringLiteral("未连接板卡，命令未发送"));
        return;
    }
    m_sock->write(proto::buildFrame(cmd, payload, m_seq++));
}

void HmiWindow::scheduleReconnect()
{
    if (m_online) return;
    if (m_retry && !m_retry->isActive())
        m_retry->start(2000);
}

void HmiWindow::onConnected()
{
    m_online = true;
    m_lblLink->setText(QStringLiteral("● 板卡在线"));
    m_lblLink->setStyleSheet(QString("color:%1; background:transparent;").arg(C_ACCENT.name()));
    logLine(QStringLiteral("已连接板卡 %1:%2").arg(m_host).arg(m_port));
    m_parser.buf.clear();
}

void HmiWindow::onDisconnected()
{
    m_online = false;
    m_lblLink->setText(QStringLiteral("● 未连接"));
    m_lblLink->setStyleSheet(QString("color:%1; background:transparent;").arg(C_RED.name()));
    logLine(QStringLiteral("连接断开，2 秒后重连"));
    scheduleReconnect();
}

void HmiWindow::onReadyRead()
{
    QList<QPair<quint8, QByteArray> > frames;
    m_parser.feed(m_sock->readAll(), &frames);
    for (int k = 0; k < frames.size(); ++k) {
        const quint8 cmd = frames.at(k).first;
        const QByteArray &pl = frames.at(k).second;
        if (cmd == proto::CMD_STATUS) {
            proto::Status st;
            if (proto::decodeStatus(pl, &st)) {
                m_last = st;
                m_haveStatus = true;
                applyStatus(st);
            }
        } else if (cmd == proto::CMD_ACK) {
            const int code = pl.isEmpty() ? -1 : quint8(pl.at(0));
            logLine(code == 0 ? QStringLiteral("命令成功")
                              : QStringLiteral("命令被拒 (code=%1)").arg(code));
        } else if (cmd == proto::CMD_NACK) {
            logLine(QStringLiteral("NACK：未知或非法命令"));
        } else if (cmd == proto::CMD_TEXT) {
            logLine(QString::fromUtf8(pl));
        }
    }
    if (m_lblStats)
        m_lblStats->setText(QStringLiteral("收帧 %1  CRC错 %2  重同步 %3")
                            .arg(m_parser.framesOk).arg(m_parser.crcErrors).arg(m_parser.resyncs));
}

void HmiWindow::applyStatus(const proto::Status &st)
{
    m_lblV->setText(QString::number(st.v_out, 'f', 2));
    m_lblI->setText(QString::number(st.i_out, 'f', 2));
    m_lblDuty->setText(QStringLiteral("%1 %").arg(st.duty, 0, 'f', 1));
    m_lblGiven->setText(QStringLiteral("给定 %1 V / %2 A")
                        .arg(st.v_set, 0, 'f', 2).arg(st.i_set, 0, 'f', 2));

    setLed(m_ledRun,  st.flags & proto::FLAG_RUNNING,     QStringLiteral("运行"));
    setLed(m_ledOut,  st.flags & proto::FLAG_OUTPUT_EN,   QStringLiteral("输出"));
    setLed(m_ledHost, st.flags & proto::FLAG_HOST_ONLINE, QStringLiteral("上位机"));
    setLed(m_ledOvp,  st.flags & proto::FLAG_OVP,         QStringLiteral("过压"));
    setLed(m_ledOcp,  st.flags & proto::FLAG_OCP,         QStringLiteral("过流"));
    setLed(m_ledOtp,  st.flags & proto::FLAG_OTP,         QStringLiteral("过温"));
    setLed(m_ledPlAct, st.pl & proto::PL_OUTPUT_ACTIVE,   QStringLiteral("PWM"));
    setLed(m_ledPlPll, st.pl & proto::PL_PLL_LOCKED,      QStringLiteral("PLL"));
    setLed(m_ledPlAdc, st.pl & proto::PL_ADC_INITIALIZED, QStringLiteral("ADC"));

    const bool fault = st.fault != proto::FAULT_NONE;
    m_lblFault->setText(QStringLiteral("故障：") + proto::faultText(st.fault));
    m_lblFault->setStyleSheet(QString("color:%1; background:transparent;")
                              .arg(fault ? C_RED.name() : C_ACCENT.name()));

    m_curve->addSample(st.v_out, st.i_out);
}

void HmiWindow::onPoll()      { send(proto::CMD_READ_STATUS); }
void HmiWindow::onHeartbeat() { send(proto::CMD_HEARTBEAT); }

void HmiWindow::onTap(const QPoint &p)
{
    for (int k = 0; k < m_hot.size(); ++k) {
        QWidget *w = m_hot.at(k).w;
        if (!w || !w->isVisible()) continue;
        const QRect r(w->mapTo(this, QPoint(0, 0)), w->size());
        if (r.contains(p)) {
            doAction(m_hot.at(k).act);
            return;
        }
    }
}

void HmiWindow::doAction(int act)
{
    switch (act) {
    case ACT_V_UP:   m_setV = qMin(60.0, m_setV + 0.5); refreshSetpointLabels(); break;
    case ACT_V_DN:   m_setV = qMax(0.0,  m_setV - 0.5); refreshSetpointLabels(); break;
    case ACT_I_UP:   break;   /* current setpoint removed from UI */
    case ACT_I_DN:   break;

    case ACT_APPLY: {
        QByteArray p;
        float v = float(m_setV), i = float(m_setI);
        quint8 vb[4], ib[4];
        std::memcpy(vb, &v, 4);
        std::memcpy(ib, &i, 4);
        p.append(reinterpret_cast<char *>(vb), 4);
        p.append(reinterpret_cast<char *>(ib), 4);
        send(proto::CMD_SET_SETPOINT, p);
        logLine(QStringLiteral("下发给定 %1 V / %2 A")
                .arg(m_setV, 0, 'f', 2).arg(m_setI, 0, 'f', 2));
        break;
    }
    case ACT_OUT_ON: {
        QByteArray p; p.append(char(1));
        send(proto::CMD_SET_OUTPUT, p);
        logLine(QStringLiteral("请求开启输出"));
        break;
    }
    case ACT_OUT_OFF: {
        QByteArray p; p.append(char(0));
        send(proto::CMD_SET_OUTPUT, p);
        logLine(QStringLiteral("请求关闭输出"));
        break;
    }
    case ACT_CLEAR:
        send(proto::CMD_CLEAR_FAULT);
        logLine(QStringLiteral("请求清除故障"));
        break;
    default: break;
    }
}
void HmiWindow::setMode(const QString &mode)
{
    if (!m_lblMode) return;
    if (mode.compare(QStringLiteral("sim"), Qt::CaseInsensitive) == 0) {
        m_lblMode->setText(QStringLiteral("仿真数据"));
        m_lblMode->setStyleSheet(QString("color:%1; background:transparent;").arg(C_AMBER.name()));
    } else {
        m_lblMode->setText(QStringLiteral("实测数据"));
        m_lblMode->setStyleSheet(QString("color:%1; background:transparent;").arg(C_ACCENT.name()));
    }
}
void HmiWindow::onNpuPoll()
{
    int code = -1;
    QFile f(QStringLiteral("/tmp/npu.status"));
    if (f.open(QIODevice::ReadOnly)) {
        bool ok = false;
        const QByteArray d = f.readAll().trimmed();
        code = d.toInt(&ok);
        if (!ok) code = -1;
        f.close();
    }
    if (!m_lblNpuStatus) return;

    if (code == 0) {
        m_lblNpuStatus->setText(QStringLiteral("● 正常"));
        m_lblNpuStatus->setStyleSheet(QString("color:%1; background:transparent;").arg(C_ACCENT.name()));
        m_lblNpuCode->setText(QStringLiteral("代码 0"));
    } else if (code == 1) {
        m_lblNpuStatus->setText(QStringLiteral("● 突变"));
        m_lblNpuStatus->setStyleSheet(QString("color:%1; background:transparent;").arg(C_RED.name()));
        m_lblNpuCode->setText(QStringLiteral("代码 1"));
    } else {
        m_lblNpuStatus->setText(QStringLiteral("● 无结果"));
        m_lblNpuStatus->setStyleSheet(QString("color:%1; background:transparent;").arg(C_DIM.name()));
        m_lblNpuCode->setText(QStringLiteral("代码 -"));
    }
}