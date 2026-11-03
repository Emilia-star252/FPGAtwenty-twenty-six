#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../../07_software/dcdc_axi/dcdc_axi.h"

int main(void)
{
    uint32_t registers[64];
    DcdcAxi dev = {0};
    DcdcStatus status;
    memset(registers, 0, sizeof(registers));
    assert(DcdcAxi_Bind(NULL, registers) == DCDC_ERR_ARGUMENT);
    assert(DcdcAxi_Bind(&dev, registers) == DCDC_ERR_HARDWARE);
    assert(DcdcAxi_SetOutput(&dev, 1) == DCDC_ERR_ARGUMENT);
    assert(DcdcAxi_ClearFaults(&dev) == DCDC_ERR_ARGUMENT);
    registers[0x54 / 4] = 0x43545231U;
    registers[0x58 / 4] = 64U * 65536U;
    assert(DcdcAxi_Bind(&dev, registers) == DCDC_OK);
    assert(DcdcAxi_SetOutput(&dev, 1) == DCDC_ERR_RANGE);
    assert(registers[0x40 / 4] == 0U);
    assert(DcdcAxi_SetVrefMilliVolt(&dev, 64000) == DCDC_OK);
    assert(registers[0x44 / 4] == 0x00400000U && registers[0x40 / 4] == 0U);
    assert(DcdcAxi_SetVrefQ16(&dev, 64 * 65536) == DCDC_OK);
    assert(DcdcAxi_SetVrefQ16(&dev, 64 * 65536 + 1) == DCDC_ERR_RANGE);
    assert(DcdcAxi_SetVrefMilliVolt(&dev, 64001) == DCDC_ERR_RANGE);
    assert(registers[0x44 / 4] == 0x00400000U && registers[0x40 / 4] == 0U);
    /* An older bitstream's limit must still be respected without recompiling the API. */
    registers[0x58 / 4] = 48U * 65536U;
    assert(DcdcAxi_SetVrefMilliVolt(&dev, 64000) == DCDC_ERR_RANGE);
    assert(registers[0x44 / 4] == 0x00400000U);
    registers[0x58 / 4] = 64U * 65536U;
    assert(DcdcAxi_SetVrefMilliVolt(&dev, 12000) == DCDC_OK);
    assert(registers[0x44 / 4] == 12U * 65536U);
    assert(registers[0x40 / 4] == 0U);
    assert(DcdcAxi_SetVrefMilliVolt(&dev, -1) == DCDC_ERR_RANGE);
    assert(DcdcAxi_SetVrefMilliVolt(&dev, 64001) == DCDC_ERR_RANGE);
    assert(DcdcAxi_SetVrefMilliVolt(&dev, INT32_MAX) == DCDC_ERR_RANGE);
    assert(DcdcAxi_SetVrefQ16(&dev, -1) == DCDC_ERR_RANGE);
    assert(registers[0x44 / 4] == 12U * 65536U);
    assert(DcdcAxi_SetOutput(&dev, 2) == DCDC_ERR_ARGUMENT);
    assert(DcdcAxi_SetOutput(&dev, 1) == DCDC_OK);
    assert(registers[0x40 / 4] == 1U);
    /* ACK/request can be true while actual PWM is still waiting for a boundary. */
    registers[0x08 / 4] = 17;
    registers[0x14 / 4] = (uint32_t)-32768;
    registers[0x18 / 4] = 65536;
    registers[0x48 / 4] = 32768;
    registers[0x4c / 4] = DCDC_OUTPUT_REQUEST | DCDC_ADC_INITIALIZED | DCDC_PLL_LOCKED;
    registers[0x50 / 4] = 6U * 65536U;
    registers[0x30 / 4] = 5;
    assert(DcdcAxi_ReadStatus(&dev, &status) == DCDC_OK);
    assert(status.sequence == 17 && status.voltage_q16 == -32768);
    assert(status.current_q16 == 65536 && status.duty_q16 == 0);
    assert(status.vref_requested_q16 == 12 * 65536 && status.vref_active_q16 == 6 * 65536);
    assert(status.dropped_frames == 5);
    registers[0x4c / 4] |= DCDC_OUTPUT_ACTIVE;
    assert(DcdcAxi_ReadStatus(&dev, &status) == DCDC_OK && status.duty_q16 == 32768);
    registers[0x4c / 4] |= DCDC_ADC_FAULT;
    assert(DcdcAxi_SetOutput(&dev, 1) == DCDC_ERR_FAULT);
    assert(DcdcAxi_SetOutput(&dev, 0) == DCDC_OK && registers[0x40 / 4] == 0);
    /* Hardware protection clears both commands, without adding fault bits. */
    registers[0x40 / 4] = 0;
    registers[0x44 / 4] = 0;
    registers[0x4c / 4] = DCDC_ADC_INITIALIZED | DCDC_PLL_LOCKED;
    assert(DcdcAxi_SetOutput(&dev, 1) == DCDC_ERR_RANGE);
    assert(registers[0x40 / 4] == 0U);
    assert(DcdcAxi_SetVrefMilliVolt(&dev, 12000) == DCDC_OK);
    assert(registers[0x40 / 4] == 0U);
    assert(DcdcAxi_SetOutput(&dev, 1) == DCDC_OK);
    assert(registers[0x40 / 4] == 1U && registers[0x44 / 4] == 12U * 65536U);
    registers[0x40 / 4] = 1;
    assert(DcdcAxi_SetVrefQ16(&dev, 0) == DCDC_OK);
    assert(registers[0x40 / 4] == 0 && registers[0x44 / 4] == 0);
    /* Old firmware must not falsely ACK a write to an unsupported clear register. */
    registers[0x40 / 4] = 1;
    registers[0x44 / 4] = 12U * 65536U;
    assert(DcdcAxi_ClearFaults(&dev) == DCDC_ERR_HARDWARE);
    assert(registers[0x40 / 4] == 1 && registers[0x44 / 4] == 12U * 65536U);
    registers[0x64 / 4] = 0x464c5431U;
    for (unsigned fault = DCDC_OVERCURRENT_FAULT; fault <= DCDC_OVERVOLTAGE_FAULT; fault <<= 1) {
        registers[0x44 / 4] = 12U * 65536U;
        registers[0x4c / 4] = fault | DCDC_ADC_INITIALIZED | DCDC_PLL_LOCKED;
        assert(DcdcAxi_SetOutput(&dev, 1) == DCDC_ERR_FAULT);
        assert(DcdcAxi_ReadStatus(&dev, &status) == DCDC_OK);
        assert((status.output_status & DCDC_SHUTDOWN_FAULTS) == fault);
        /* Memory mock retains faults; integration simulation checks actual PL clearing. */
        assert(DcdcAxi_ClearFaults(&dev) == DCDC_ERR_FAULT);
        assert(registers[0x40 / 4] == 0 && registers[0x44 / 4] == 0);
        assert(registers[0x60 / 4] == 1U && (registers[0x4c / 4] & fault));
    }
    registers[0x4c / 4] = DCDC_ADC_FAULT;
    assert(DcdcAxi_ClearFaults(&dev) == DCDC_ERR_FAULT);
    registers[0x4c / 4] = DCDC_ADC_INITIALIZED | DCDC_PLL_LOCKED;
    registers[0x40 / 4] = 1;
    registers[0x44 / 4] = 12U * 65536U;
    assert(DcdcAxi_ClearFaults(&dev) == DCDC_OK);
    assert(registers[0x40 / 4] == 0 && registers[0x44 / 4] == 0);
    assert(DcdcAxi_ReadStatus(&dev, NULL) == DCDC_ERR_ARGUMENT);
    assert(DcdcAxi_Bind(&dev, NULL) == DCDC_ERR_ARGUMENT && dev.regs == NULL);
    puts("DCDC_AXI_API_TEST_PASS: fault upload/masks, clear capability check, residual/ADC faults refuse success, clear leaves OFF/VREF=0, 64 V commands");
    return 0;
}
