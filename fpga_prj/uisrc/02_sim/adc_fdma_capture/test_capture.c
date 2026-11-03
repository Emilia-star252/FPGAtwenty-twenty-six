/* Host register/buffer model tests for the production capture controller.
 * These are NOT PS/DDR/ADC hardware or NPU arithmetic tests.
 */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "capture.h"
#include "../adc_fdma/dcdc_adc_fdma_regs.h"

enum Scenario { SUCCESS, BAD_ID, REJECT_CONFIG, STALL, DMA_ERROR, DROP,
                BUS_STUCK, RESET_STUCK, FIFO_STUCK, BAD_COUNT };
typedef struct Model {
    enum Scenario scenario;
    uint32_t control, slots, lo, hi, producer, error, drops, fifo;
    uint64_t ms;
    unsigned writes, prepared, finished, reset_requested, started;
} Model;
static unsigned char buffer[8192] __attribute__((aligned(4096)));
static const uintptr_t dc = 0x80000000u, fd = 0x80010000u;

static uint32_t read_reg(void *context, uintptr_t a)
{
    Model *m = context;
    if (a == dc) return m->scenario == BAD_ID ? 0 : 0x41444331;
    if (a == dc + 0x54) return 0x43545231;
    if (a == dc + 0x64) return 0x464c5431;
    if (a == dc + 0x34 || a == fd + 0x28) return 0x50343831;
    if (a == dc + 0x4c) return 2;
    if (a == dc + 0x08) return (uint32_t)m->ms * 25;
    if (a == dc + 0x20) return m->scenario == FIFO_STUCK ? 4 : 0;
    if (a == dc + 0x30) return m->drops;
    if (a == fd) return 0x46444d31;
    if (a == fd + 0x04) return m->control;
    if (a == fd + 0x08) {
        int busy = (m->scenario == BUS_STUCK && m->started) ||
                   (m->control == 1 && m->producer < m->slots);
        return (m->control == 1) | ((uint32_t)busy << 1) |
               ((uint32_t)(m->slots && m->producer >= m->slots) << 2) |
               ((uint32_t)(m->error != 0) << 3) |
               (m->scenario == REJECT_CONFIG ? 0 : 16);
    }
    if (a == fd + 0x0c) return m->error;
    if (a == fd + 0x10) return m->lo;
    if (a == fd + 0x14) return m->hi;
    if (a == fd + 0x18) return m->slots;
    if (a == fd + 0x1c) return m->producer;
    if (a == fd + 0x20) return 0;
    if (a == fd + 0x24) return 4096;
    assert(!"read outside current public register contract");
    return 0;
}
static void write_reg(void *context, uintptr_t a, uint32_t v)
{
    Model *m = context;
    ++m->writes;
    /* Fail any accidental power ON/OFF/Vref/fault-clear or CONSUMER write. */
    assert(a == dc + 0x2c || a == fd + 4 || a == fd + 0x10 ||
           a == fd + 0x14 || a == fd + 0x18);
    if (a == dc + 0x2c) { m->fifo = v == 1; if (v == 2) m->drops = 0; }
    if (a == fd + 4) {
        m->control = v;
        if (v == 2) {
            m->reset_requested = 1;
            if (m->scenario != RESET_STUCK) m->control = m->producer = m->error = 0;
        }
        if (v == 1) { assert(m->prepared); m->started = 1; }
    }
    if (a == fd + 0x10) m->lo = v;
    if (a == fd + 0x14) m->hi = v;
    if (a == fd + 0x18) m->slots = v;
}
static uint64_t clock_ms(void *context) { return ((Model *)context)->ms; }
static void advance(void *context, unsigned ms)
{
    Model *m = context;
    m->ms += ms;
    if (m->control != 1 || !m->fifo) return;
    if (m->scenario == DMA_ERROR) { m->error = 2; return; }
    if (m->scenario == DROP) { m->drops = 1; return; }
    if (m->scenario == STALL || m->scenario == BUS_STUCK) return;
    if (m->scenario == BAD_COUNT) { m->producer = m->slots + 1; return; }
    if (m->producer < m->slots) {
        memset(buffer + m->producer * 4096, (int)m->producer, 4096);
        ++m->producer;
    }
}
static void prepare(void *context, void *p, size_t n)
{ Model *m = context; assert(p == buffer && n == sizeof(buffer)); ++m->prepared; }
static void finish(void *context, void *p, size_t n)
{ Model *m = context; assert(p == buffer && n == sizeof(buffer)); ++m->finished; }

static void run(enum Scenario scenario, int expected)
{
    Model m = {.scenario = scenario};
    CaptureIo io = {&m, read_reg, write_reg, clock_ms, advance, prepare, finish};
    CaptureConfig cfg = {0x08000000, buffer, sizeof(buffer), 2, 25000, 10, 3};
    CaptureInfo info;
    int actual = Capture_Run(&cfg, &io, &info);
    assert(actual == expected && info.result == (unsigned)expected);
    if (scenario == SUCCESS) {
        assert(info.phase == 3 && info.flags == 3 && info.valid_bytes == sizeof(buffer));
        assert(info.sample_count == 512 && info.completed_blocks == 2 && info.consumer == 0);
        assert(info.crc32 == Capture_Crc32(buffer, sizeof(buffer)));
        assert(m.finished == 1 && m.control == 0 && m.fifo == 0);
    } else {
        assert(info.phase != 3 && !(info.flags & CAPTURE_FLAG_CRC_VALID));
        if (scenario == BAD_ID) assert(!m.writes && !m.prepared && !m.finished);
        if (scenario == BUS_STUCK || scenario == RESET_STUCK) {
            assert(info.phase == CAPTURE_PHASE_UNSAFE && !m.finished && !info.valid_bytes);
        }
    }
    printf("CAPTURE_HOST_CASE_PASS scenario=%d result=%d\n", scenario, actual);
}
int main(void)
{
    assert(Capture_Crc32((const uint8_t *)"123456789", 9) == 0xcbf43926u);
    run(SUCCESS, CAPTURE_OK); run(BAD_ID, CAPTURE_BAD_ID);
    run(REJECT_CONFIG, CAPTURE_CONFIG_REJECTED); run(STALL, CAPTURE_TIMEOUT);
    run(DMA_ERROR, CAPTURE_DMA_ERROR); run(DROP, CAPTURE_DROPPED);
    run(BUS_STUCK, CAPTURE_DRAIN_TIMEOUT); run(RESET_STUCK, CAPTURE_RESET_TIMEOUT);
    run(FIFO_STUCK, CAPTURE_FIFO_TIMEOUT); run(BAD_COUNT, CAPTURE_COUNT_ERROR);
    Model m = {0}; CaptureInfo info;
    CaptureIo io = {&m, read_reg, write_reg, clock_ms, advance, prepare, finish};
    CaptureConfig invalid = {0x08000001, buffer, sizeof(buffer), 2, 25000, 10, 3};
    assert(Capture_Run(&invalid, &io, &info) == CAPTURE_BAD_CONFIG && !m.writes);
    uint8_t negative[6] = {0, 0, 0xfe, 0xff, 0xff, 0xff};
    assert(DcdcFdma_DecodeSigned48(negative) == -131072);
    puts("CAPTURE_HOST_CONTROLLER_ALL_PASS");
    return 0;
}
