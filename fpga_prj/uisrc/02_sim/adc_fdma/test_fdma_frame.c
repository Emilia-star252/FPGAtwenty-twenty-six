#include "../../07_software/adc_fdma/dcdc_adc_fdma_regs.h"
#include <assert.h>
#include <stddef.h>
int main(void)
{
    const dcdc_fdma_u8 minimum[6]={0,0,0,0,0,0x80};
    const dcdc_fdma_u8 maximum[6]={255,255,255,255,255,0x7f};
    const dcdc_fdma_u8 minus_one[6]={255,255,255,255,255,255};
    const dcdc_fdma_u8 wide[6]={0,0,0,0x80,0x34,0x12};
    DcdcAdcFdmaFrameLe f={{0},{0},{0,0x80,0,0}};
    assert(offsetof(DcdcAdcFdmaFrameLe,current_product_le)==6);
    assert(offsetof(DcdcAdcFdmaFrameLe,duty_q16_le)==12);
    assert(DcdcFdma_DecodeSigned48(minimum)==-140737488355328LL);
    assert(DcdcFdma_DecodeSigned48(maximum)==140737488355327LL);
    assert(DcdcFdma_DecodeSigned48(minus_one)==-1);
    assert(DcdcFdma_DecodeSigned48(wide)==0x123480000000LL);
    assert(DcdcFdma_DecodeDuty(&f)==32768);
    return 0;
}
