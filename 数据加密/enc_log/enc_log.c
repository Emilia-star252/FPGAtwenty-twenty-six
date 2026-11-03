/*
 * enc_log —— 把 stdin 的一批明文加密成一条记录，追加到输出文件
 *
 * 记录格式（全部小端）：
 *   [4 B  明文长度 len]
 *   [16 B 随机 IV（后 4 字节是 CTR 计数器，起始 0）]
 *   [len B AES-256-CTR 密文]
 *
 * 用法：
 *   enc_log -k /etc/log.key -o /data/powerlog/power.enc < batch.csv
 *   enc_log -k /etc/log.key -g            # 生成 32 字节密钥（若不存在）
 *
 * AES-256 完全自己实现（S-box 用 GF(2^8) 逆元+仿射变换现算，不查表打字），
 * 可用 `enc_log -t` 自检（FIPS-197 附录 C.3 测试向量）。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <sys/stat.h>

/* ---------------- AES-256 ---------------- */
static uint8_t sbox[256];

static uint8_t xtime(uint8_t x) { return (uint8_t)((x << 1) ^ ((x & 0x80) ? 0x1b : 0x00)); }

static uint8_t gmul(uint8_t a, uint8_t b)
{
    uint8_t p = 0;
    for (int i = 0; i < 8; i++) {
        if (b & 1) p ^= a;
        a = xtime(a);
        b >>= 1;
    }
    return p;
}

static void init_sbox(void)
{
    for (int i = 0; i < 256; i++) {
        uint8_t x = (uint8_t)i, inv = 0;
        if (x) {
            uint8_t r = 1;
            for (int e = 0; e < 254; e++) r = gmul(r, x);   /* x^254 = x^-1 */
            inv = r;
        }
        uint8_t s1 = (uint8_t)((inv << 1) | (inv >> 7));
        uint8_t s2 = (uint8_t)((inv << 2) | (inv >> 6));
        uint8_t s3 = (uint8_t)((inv << 3) | (inv >> 5));
        uint8_t s4 = (uint8_t)((inv << 4) | (inv >> 4));
        sbox[i] = (uint8_t)(inv ^ s1 ^ s2 ^ s3 ^ s4 ^ 0x63);
    }
}

/* AES-256: Nk=8, Nr=14, 15 组轮密钥（每组 16 B） */
static void key_expand(const uint8_t key[32], uint8_t rk[15][16])
{
    uint8_t w[60][4];
    const int Nk = 8, Nr = 14, total = 4 * (Nr + 1);
    memcpy(w, key, 32);
    uint8_t rcon = 1;
    for (int i = Nk; i < total; i++) {
        uint8_t t[4];
        memcpy(t, w[i - 1], 4);
        if (i % Nk == 0) {
            uint8_t tmp = t[0];
            t[0] = (uint8_t)(sbox[t[1]] ^ rcon);
            t[1] = sbox[t[2]];
            t[2] = sbox[t[3]];
            t[3] = sbox[tmp];
            rcon = xtime(rcon);
        } else if ((i % Nk) == 4) {
            for (int k = 0; k < 4; k++) t[k] = sbox[t[k]];
        }
        for (int k = 0; k < 4; k++) w[i][k] = (uint8_t)(w[i - Nk][k] ^ t[k]);
    }
    for (int i = 0; i < total; i++) memcpy(rk[i / 4] + 4 * (i % 4), w[i], 4);
}

static void aes_encrypt_block(const uint8_t rk[15][16], const uint8_t in[16], uint8_t out[16])
{
    const int Nr = 14;
    uint8_t s[16];
    memcpy(s, in, 16);
    for (int i = 0; i < 16; i++) s[i] ^= rk[0][i];

    for (int round = 1; round <= Nr; round++) {
        for (int i = 0; i < 16; i++) s[i] = sbox[s[i]];        /* SubBytes */

        uint8_t t;                                              /* ShiftRows（列主序） */
        t = s[1];  s[1]  = s[5];  s[5]  = s[9];  s[9]  = s[13]; s[13] = t;
        t = s[2];  s[2]  = s[10]; s[10] = t;
        t = s[6];  s[6]  = s[14]; s[14] = t;
        t = s[15]; s[15] = s[11]; s[11] = s[7];  s[7]  = s[3];  s[3]  = t;

        if (round != Nr) {                                      /* MixColumns */
            for (int c = 0; c < 4; c++) {
                uint8_t *col = s + 4 * c;
                uint8_t a0 = col[0], a1 = col[1], a2 = col[2], a3 = col[3];
                col[0] = (uint8_t)(gmul(a0, 2) ^ gmul(a1, 3) ^ a2 ^ a3);
                col[1] = (uint8_t)(a0 ^ gmul(a1, 2) ^ gmul(a2, 3) ^ a3);
                col[2] = (uint8_t)(a0 ^ a1 ^ gmul(a2, 2) ^ gmul(a3, 3));
                col[3] = (uint8_t)(gmul(a0, 3) ^ a1 ^ a2 ^ gmul(a3, 2));
            }
        }
        for (int i = 0; i < 16; i++) s[i] ^= rk[round][i];      /* AddRoundKey */
    }
    memcpy(out, s, 16);
}

/* CTR：IV 后 4 字节为大端计数器，起始 0 */
static void aes_ctr(const uint8_t rk[15][16], uint8_t iv[16], const uint8_t *in, uint8_t *out, size_t n)
{
    uint8_t ctr[16], ks[16];
    memcpy(ctr, iv, 16);
    uint32_t c = 0;
    for (size_t off = 0; off < n; off += 16) {
        ctr[12] = (uint8_t)(c >> 24); ctr[13] = (uint8_t)(c >> 16);
        ctr[14] = (uint8_t)(c >> 8);  ctr[15] = (uint8_t)c;
        aes_encrypt_block(rk, ctr, ks);
        size_t m = (n - off < 16) ? (n - off) : 16;
        for (size_t i = 0; i < m; i++) out[off + i] = (uint8_t)(in[off + i] ^ ks[i]);
        c++;
    }
}

/* ---------------- 工具 ---------------- */
static int read_all(FILE *f, uint8_t **buf, size_t *len)
{
    size_t cap = 8192, n = 0;
    uint8_t *p = malloc(cap);
    if (!p) return -1;
    for (;;) {
        if (n == cap) {
            cap *= 2;
            uint8_t *q = realloc(p, cap);
            if (!q) { free(p); return -1; }
            p = q;
        }
        size_t r = fread(p + n, 1, cap - n, f);
        n += r;
        if (r == 0) break;
    }
    *buf = p; *len = n;
    return 0;
}

static int load_key(const char *path, uint8_t key[32])
{
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    size_t r = fread(key, 1, 32, f);
    fclose(f);
    return (r == 32) ? 0 : -1;
}

static int gen_key(const char *path)
{
    uint8_t k[32];
    int fd = open("/dev/urandom", O_RDONLY);
    if (fd < 0) { perror("open /dev/urandom"); return -1; }
    size_t got = 0;
    while (got < 32) {
        ssize_t r = read(fd, k + got, 32 - got);
        if (r <= 0) { close(fd); return -1; }
        got += (size_t)r;
    }
    close(fd);
    int out = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (out < 0) { perror(path); return -1; }
    if (write(out, k, 32) != 32) { close(out); return -1; }
    close(out);
    printf("key generated: %s (32 bytes, 0600)\n", path);
    return 0;
}

/* FIPS-197 附录 C.3 自检 */
static int selftest(void)
{
    const uint8_t key[32] = {
        0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,
        0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f };
    const uint8_t pt[16] = {
        0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xaa,0xbb,0xcc,0xdd,0xee,0xff };
    const uint8_t expect[16] = {
        0x8e,0xa2,0xb7,0xca,0x51,0x67,0x45,0xbf,0xea,0xfc,0x49,0x90,0x4b,0x49,0x60,0x89 };
    uint8_t rk[15][16], out[16];
    key_expand(key, rk);
    aes_encrypt_block(rk, pt, out);
    int ok = memcmp(out, expect, 16) == 0;
    printf("selftest: %s\n", ok ? "PASS (FIPS-197 C.3)" : "FAIL");
    if (!ok) {
        printf("  got     : ");
        for (int i = 0; i < 16; i++) printf("%02x", out[i]);
        printf("\n  expected: ");
        for (int i = 0; i < 16; i++) printf("%02x", expect[i]);
        printf("\n");
    }
    return ok ? 0 : 1;
}

static int write_all(int fd, const void *buf, size_t n)
{
    const uint8_t *p = buf;
    while (n) {
        ssize_t w = write(fd, p, n);
        if (w < 0) { if (errno == EINTR) continue; return -1; }
        p += w; n -= (size_t)w;
    }
    return 0;
}

int main(int argc, char **argv)
{
    const char *keyfile = "/etc/log.key";
    const char *outfile = NULL;
    int do_gen = 0, do_test = 0;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-k") && i + 1 < argc) keyfile = argv[++i];
        else if (!strcmp(argv[i], "-o") && i + 1 < argc) outfile = argv[++i];
        else if (!strcmp(argv[i], "-g")) do_gen = 1;
        else if (!strcmp(argv[i], "-t")) do_test = 1;
        else {
            fprintf(stderr,
                "用法: %s [-k KEYFILE] [-o OUTFILE] [-g] [-t]\n"
                "  -k  密钥文件（默认 /etc/log.key，32 字节）\n"
                "  -o  密文输出文件（追加）\n"
                "  -g  生成密钥（若不存在）\n"
                "  -t  AES 自检（FIPS-197 向量）\n"
                "明文从 stdin 读；每条记录 = [len u32][IV 16B][AES-256-CTR 密文]\n", argv[0]);
            return 2;
        }
    }

    init_sbox();
    if (do_test) return selftest();
    if (do_gen) return gen_key(keyfile) == 0 ? 0 : 1;

    if (!outfile) { fprintf(stderr, "缺少 -o\n"); return 2; }

    uint8_t key[32];
    if (load_key(keyfile, key) != 0) {
        fprintf(stderr, "读不到密钥 %s（先跑 %s -g）\n", keyfile, argv[0]);
        return 1;
    }

    uint8_t *plain = NULL;
    size_t plen = 0;
    if (read_all(stdin, &plain, &plen) != 0) { fprintf(stderr, "读 stdin 失败\n"); return 1; }
    if (plen == 0) { free(plain); return 0; }                 /* 没数据不写 */
    if (plen > (64u << 20)) { fprintf(stderr, "批次过大: %zu\n", plen); free(plain); return 1; }

    uint8_t rk[15][16], iv[16];
    key_expand(key, rk);
    int fd = open("/dev/urandom", O_RDONLY);
    if (fd < 0 || read(fd, iv, 16) != 16) { perror("/dev/urandom"); if (fd >= 0) close(fd); free(plain); return 1; }
    close(fd);
    iv[12] = iv[13] = iv[14] = iv[15] = 0;                    /* 后 4 字节留给计数器 */

    uint8_t *ct = malloc(plen);
    if (!ct) { free(plain); return 1; }
    aes_ctr(rk, iv, plain, ct, plen);

    int out = open(outfile, O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (out < 0) { perror(outfile); free(plain); free(ct); return 1; }

    uint8_t hdr[4] = { (uint8_t)plen, (uint8_t)(plen >> 8), (uint8_t)(plen >> 16), (uint8_t)(plen >> 24) };
    if (write_all(out, hdr, 4) || write_all(out, iv, 16) || write_all(out, ct, plen)) {
        perror("write"); close(out); free(plain); free(ct); return 1;
    }
    close(out);
    free(plain); free(ct);
    return 0;
}
