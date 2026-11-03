// main.cpp -- entry point for the power monitor HMI (1024x600 linuxfb)
#include <QApplication>
#include <QFont>
#include <QFontInfo>
#include <QTextCodec>
#include <QStringList>
#include <cstdio>
#include "hmi.h"

int main(int argc, char *argv[])
{
    // make sure UTF-8 strings render (board has no locale by default)
    QTextCodec::setCodecForLocale(QTextCodec::codecForName("UTF-8"));

    QApplication app(argc, argv);

    QString host = QStringLiteral("192.168.137.101");
    quint16 port = 5000;
    QString touchDev = QStringLiteral("/dev/input/event0");
    QString mode = QStringLiteral("sim");

    const QStringList args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        if (args[i] == QStringLiteral("--host") && i + 1 < args.size())
            host = args[++i];
        else if (args[i] == QStringLiteral("--mode") && i + 1 < args.size())
            mode = args[++i];
        else if (args[i] == QStringLiteral("--touch") && i + 1 < args.size())
            touchDev = args[++i];
        else if (args[i] == QStringLiteral("--port") && i + 1 < args.size())
            port = quint16(args[++i].toUInt());
        else if (args[i] == QStringLiteral("--help")) {
            std::printf("usage: %s [--host IP] [--port PORT] [--touch DEV] [--mode sim|real]\n", argv[0]);
            return 0;
        }
    }

    // pick the first CJK-capable font that actually exists on this rootfs
    const QStringList families = {
        QStringLiteral("WenQuanYi Zen Hei"),      // wqy-zenhei.ttc (present on the board)
        QStringLiteral("WenQuanYi Micro Hei"),
        QStringLiteral("Noto Sans CJK SC"),
        QStringLiteral("Droid Sans Fallback"),
        QStringLiteral("DejaVu Sans")
    };
    QFont f = app.font();
    for (const QString &fam : families) {
        f.setFamily(fam);
        if (QFontInfo(f).family().compare(fam, Qt::CaseInsensitive) == 0) {
            std::printf("using font: %s\n", qPrintable(fam));
            break;
        }
    }
    f.setPixelSize(16);
    app.setFont(f);

    HmiWindow w(host, port, touchDev);
    w.setMode(mode);
    w.setWindowTitle(QStringLiteral("Power Monitor"));
    w.showFullScreen();

    return app.exec();
}
