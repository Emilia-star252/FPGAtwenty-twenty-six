#!/usr/bin/env python3
"""decrypt_log.py —— 解密 enc_log 生成的 .enc 日志（纯标准库，无第三方依赖）

记录格式（小端）：
    [4 B 明文长度][16 B IV（后 4 字节为计数器，起始 0）][AES-256-CTR 密文]

用法：
    python decrypt_log.py power.enc power.csv --key-file log.key
    python decrypt_log.py power.enc -        --key-file log.key      # 输出到 stdout
    python decrypt_log.py --selftest                                  # AES 自检

密钥：32 字节二进制文件（板上 /etc/log.key, 权限 0600）
"""
import sys
import struct


# ---------------- AES-256（纯 Python，仅加密方向，CTR 通用） ----------------
def _xtime(x):
    return ((x << 1) ^ (0x1B if x & 0x80 else 0)) & 0xFF


def _gmul(a, b):
    p = 0
    for _ in range(8):
        if b & 1:
            p ^= a
        a = _xtime(a)
        b >>= 1
    return p & 0xFF


def _make_sbox():
    box = [0] * 256
    for i in range(256):
        inv = 0
        if i:
            r = 1
            for _ in range(254):
                r = _gmul(r, i)
            inv = r
        s1 = ((inv << 1) | (inv >> 7)) & 0xFF
        s2 = ((inv << 2) | (inv >> 6)) & 0xFF
        s3 = ((inv << 3) | (inv >> 5)) & 0xFF
        s4 = ((inv << 4) | (inv >> 4)) & 0xFF
        box[i] = inv ^ s1 ^ s2 ^ s3 ^ s4 ^ 0x63
    return box


SBOX = _make_sbox()


def key_expand(key):
    """AES-256: Nk=8, Nr=14 -> 15 轮密钥，每个 16 B"""
    nk, nr = 8, 14
    total = 4 * (nr + 1)
    w = [list(key[4 * i:4 * i + 4]) for i in range(nk)]
    rcon = 1
    for i in range(nk, total):
        t = list(w[i - 1])
        if i % nk == 0:
            t = [SBOX[t[1]] ^ rcon, SBOX[t[2]], SBOX[t[3]], SBOX[t[0]]]
            rcon = _xtime(rcon)
        elif i % nk == 4:
            t = [SBOX[x] for x in t]
        w.append([w[i - nk][k] ^ t[k] for k in range(4)])
    rk = []
    for r in range(nr + 1):
        block = []
        for c in range(4):
            block.extend(w[4 * r + c])
        rk.append(block)
    return rk


def encrypt_block(rk, block):
    nr = 14
    s = list(block)
    for i in range(16):
        s[i] ^= rk[0][i]
    for rnd in range(1, nr + 1):
        s = [SBOX[x] for x in s]
        s[1], s[5], s[9], s[13] = s[5], s[9], s[13], s[1]
        s[2], s[10] = s[10], s[2]
        s[6], s[14] = s[14], s[6]
        s[3], s[7], s[11], s[15] = s[15], s[3], s[7], s[11]
        if rnd != nr:
            for c in range(4):
                i = 4 * c
                a0, a1, a2, a3 = s[i], s[i + 1], s[i + 2], s[i + 3]
                s[i] = _gmul(a0, 2) ^ _gmul(a1, 3) ^ a2 ^ a3
                s[i + 1] = a0 ^ _gmul(a1, 2) ^ _gmul(a2, 3) ^ a3
                s[i + 2] = a0 ^ a1 ^ _gmul(a2, 2) ^ _gmul(a3, 3)
                s[i + 3] = _gmul(a0, 3) ^ a1 ^ a2 ^ _gmul(a3, 2)
        for i in range(16):
            s[i] ^= rk[rnd][i]
    return bytes(s)


def aes_ctr(rk, iv, data):
    out = bytearray(len(data))
    ctr = bytearray(iv)
    c = 0
    for off in range(0, len(data), 16):
        ctr[12:16] = struct.pack('>I', c & 0xFFFFFFFF)
        ks = encrypt_block(rk, ctr)
        chunk = data[off:off + 16]
        for i, b in enumerate(chunk):
            out[off + i] = b ^ ks[i]
        c += 1
    return bytes(out)


# ---------------- 记录解析 ----------------
def decrypt_records(blob, key):
    rk = key_expand(key)
    pos, out, nrec = 0, bytearray(), 0
    while pos + 20 <= len(blob):
        (n,) = struct.unpack_from('<I', blob, pos)
        iv = blob[pos + 4:pos + 20]
        start = pos + 20
        if n == 0 or start + n > len(blob):
            print('[warn] 记录 #%d 长度异常(%d)，停止' % (nrec + 1, n), file=sys.stderr)
            break
        out += aes_ctr(rk, iv, blob[start:start + n])
        pos = start + n
        nrec += 1
    if pos != len(blob):
        print('[warn] 有 %d 字节尾部残留（可能断电截断）' % (len(blob) - pos), file=sys.stderr)
    return bytes(out), nrec


def selftest():
    key = bytes(range(32))
    pt = bytes.fromhex('00112233445566778899aabbccddeeff')
    expect = bytes.fromhex('8ea2b7ca516745bfeafc49904b496089')
    rk = key_expand(key)
    got = encrypt_block(rk, pt)
    ok = got == expect
    print('selftest:', 'PASS (FIPS-197 C.3)' if ok else 'FAIL')
    if not ok:
        print(' got     :', got.hex())
        print(' expected:', expect.hex())
    return 0 if ok else 1


def main(argv):
    if '--selftest' in argv:
        return selftest()
    args = [a for a in argv[1:] if not a.startswith('--')]
    keyfile = None
    for i, a in enumerate(argv):
        if a == '--key-file' and i + 1 < len(argv):
            keyfile = argv[i + 1]
    args = [a for a in args if a != keyfile]
    if len(args) < 2 or not keyfile:
        print(__doc__)
        return 2
    src, dst = args[0], args[1]
    with open(keyfile, 'rb') as f:
        key = f.read()
    if len(key) != 32:
        print('密钥必须是 32 字节（当前 %d）' % len(key), file=sys.stderr)
        return 1
    with open(src, 'rb') as f:
        blob = f.read()
    data, nrec = decrypt_records(blob, key)
    if dst == '-':
        sys.stdout.write(data.decode('utf-8', 'replace'))
    else:
        with open(dst, 'wb') as f:
            f.write(data)
        print('解密完成: %d 条记录, %d 字节明文 -> %s' % (nrec, len(data), dst))


if __name__ == '__main__':
    sys.exit(main(sys.argv))
