// protocol.h -- DC-DC power board protocol (mirrors protocol.py, the single source of truth)
//
// frame:  AA 55 | LEN | CMD | SEQ | PAYLOAD | CRC16_LO CRC16_HI
//   LEN        = 2 + payload size            (min 2, max 66)
//   CRC16      = MODBUS (poly 0xA001, init 0xFFFF), over LEN..payload end
//   frame size = LEN + 5
//
// commands (PC -> board): 0x01 READ_STATUS, 0x02 SET_SETPOINT(<ff>), 0x03 SET_OUTPUT(<B>),
//                         0x04 HEARTBEAT, 0x05 CLEAR_FAULT, 0x06 SET_TIME(<Q>)
//          (board -> PC): 0x81 ACK(<B>), 0x82 STATUS(26 bytes), 0x83 NACK(<B>), 0x84 TEXT(utf8)
//
// STATUS payload (26 bytes, little endian, no padding): <HfffffHH>
//   flags u16, v_out f32, i_out f32, duty f32, v_set f32, i_set f32, fault u16, pl_status u16
#ifndef PROTOCOL_H
#define PROTOCOL_H

#include <QByteArray>
#include <QtGlobal>
#include <QString>
#include <QList>
#include <QPair>
#include <cstring>

namespace proto {

static const quint8  SOF1 = 0xAA;
static const quint8  SOF2 = 0x55;
static const int     MAX_PAYLOAD    = 64;
static const int     MIN_LEN        = 2;
static const int     MAX_LEN        = MIN_LEN + MAX_PAYLOAD;
static const int     FRAME_OVERHEAD = 5;

enum Cmd {
    CMD_READ_STATUS  = 0x01,
    CMD_SET_SETPOINT = 0x02,
    CMD_SET_OUTPUT   = 0x03,
    CMD_HEARTBEAT    = 0x04,
    CMD_CLEAR_FAULT  = 0x05,
    CMD_SET_TIME     = 0x06,
    CMD_ACK          = 0x81,
    CMD_STATUS       = 0x82,
    CMD_NACK         = 0x83,
    CMD_TEXT         = 0x84
};

// flags bits
static const quint16 FLAG_RUNNING     = 1 << 0;
static const quint16 FLAG_OUTPUT_EN   = 1 << 1;
static const quint16 FLAG_OVP         = 1 << 2;
static const quint16 FLAG_OCP         = 1 << 3;
static const quint16 FLAG_OTP         = 1 << 4;
static const quint16 FLAG_HOST_ONLINE = 1 << 5;
static const quint16 FLAG_LOG_OK      = 1 << 6;

// PL status bits
static const quint16 PL_OUTPUT_REQUEST = 1 << 0;
static const quint16 PL_OUTPUT_ACTIVE  = 1 << 1;
static const quint16 PL_ADC_INITIALIZED= 1 << 2;
static const quint16 PL_ADC_ERROR      = 1 << 3;
static const quint16 PL_PLL_LOCKED     = 1 << 4;
static const quint16 PL_PWM_ARMED      = 1 << 5;
static const quint16 PL_SAMPLE_OVERRUN = 1 << 6;

// fault codes
enum Fault {
    FAULT_NONE = 0, FAULT_OVP = 1, FAULT_OCP = 2, FAULT_OTP = 3,
    FAULT_ADC = 4, FAULT_OVERRUN = 5
};

inline QString faultText(quint16 f)
{
    switch (f) {
    case FAULT_NONE:    return QStringLiteral("无");
    case FAULT_OVP:     return QStringLiteral("过压保护 (OVP)");
    case FAULT_OCP:     return QStringLiteral("过流保护 (OCP)");
    case FAULT_OTP:     return QStringLiteral("过温保护 (OTP)");
    case FAULT_ADC:     return QStringLiteral("ADC 故障锁存");
    case FAULT_OVERRUN: return QStringLiteral("采样溢出");
    default:            return QStringLiteral("未知故障 (%1)").arg(f);
    }
}

inline quint16 crc16(const quint8 *data, int len)
{
    quint16 crc = 0xFFFF;
    for (int i = 0; i < len; ++i) {
        crc ^= data[i];
        for (int b = 0; b < 8; ++b)
            crc = (crc & 1) ? quint16((crc >> 1) ^ 0xA001) : quint16(crc >> 1);
    }
    return crc;
}

inline QByteArray buildFrame(quint8 cmd, const QByteArray &payload = QByteArray(), quint8 seq = 0)
{
    QByteArray f;
    quint8 len = quint8(MIN_LEN + payload.size());
    f.append(char(SOF1));
    f.append(char(SOF2));
    f.append(char(len));
    f.append(char(cmd));
    f.append(char(seq));
    f.append(payload);

    QByteArray crcRegion = f.mid(2);                       // LEN..payload end
    quint16 crc = crc16(reinterpret_cast<const quint8 *>(crcRegion.constData()), crcRegion.size());
    f.append(char(crc & 0xFF));
    f.append(char((crc >> 8) & 0xFF));
    return f;
}

struct Status {
    quint16 flags   = 0;
    float   v_out   = 0.f;
    float   i_out   = 0.f;
    float   duty    = 0.f;
    float   v_set   = 0.f;
    float   i_set   = 0.f;
    quint16 fault   = FAULT_NONE;
    quint16 pl      = 0;
};

inline bool decodeStatus(const QByteArray &p, Status *st)
{
    if (p.size() != 26 || !st) return false;
    const quint8 *d = reinterpret_cast<const quint8 *>(p.constData());
    auto rd16 = [&](int off) { return quint16(d[off] | (d[off + 1] << 8)); };
    auto rd32 = [&](int off) {
        quint32 v = quint32(d[off]) | (quint32(d[off + 1]) << 8) |
                    (quint32(d[off + 2]) << 16) | (quint32(d[off + 3]) << 24);
        float f; std::memcpy(&f, &v, 4); return f;
    };
    st->flags = rd16(0);
    st->v_out = rd32(2);
    st->i_out = rd32(6);
    st->duty  = rd32(10);
    st->v_set = rd32(14);
    st->i_set = rd32(18);
    st->fault = rd16(22);
    st->pl    = rd16(24);
    return true;
}

// incremental stream parser (resync-safe)
class Parser {
public:
    QByteArray buf;
    int crcErrors = 0, resyncs = 0, framesOk = 0, bytesDropped = 0;

    void feed(const QByteArray &data, QList<QPair<quint8, QByteArray>> *out)
    {
        buf.append(data);
        for (;;) {
            const int idx = buf.indexOf(QByteArray(1, char(SOF1)) + QByteArray(1, char(SOF2)));
            if (idx < 0) {
                if (buf.size() > 1) {
                    const int drop = buf.size() - 1;
                    buf.remove(0, drop);
                    bytesDropped += drop;
                }
                return;
            }
            if (idx > 0) {
                buf.remove(0, idx);
                bytesDropped += idx;
                ++resyncs;
            }
            if (buf.size() < 3) return;
            const int len = quint8(buf.at(2));
            if (len < MIN_LEN || len > MAX_LEN) {
                buf.remove(0, 1); ++bytesDropped; ++resyncs; continue;
            }
            const int total = len + FRAME_OVERHEAD;
            if (buf.size() < total) return;                 // half packet

            const quint16 crcCalc = crc16(reinterpret_cast<const quint8 *>(buf.constData()) + 2, total - 4);
            const quint16 crcRecv = quint8(buf.at(total - 2)) | (quint8(buf.at(total - 1)) << 8);
            if (crcCalc != crcRecv) {
                ++crcErrors; buf.remove(0, 1); ++bytesDropped; ++resyncs; continue;
            }
            const quint8 cmd = quint8(buf.at(3));
            const QByteArray payload = buf.mid(5, total - 7);
            if (out) out->append(qMakePair(cmd, payload));
            buf.remove(0, total);
            ++framesOk;
        }
    }
};

} // namespace proto

#endif // PROTOCOL_H
