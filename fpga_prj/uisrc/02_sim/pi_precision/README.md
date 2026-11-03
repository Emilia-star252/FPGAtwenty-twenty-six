# PI fractional integration regression

The project source is `uisrc/01_rtl/PI.v`. The separate historical
`uisrc/02_sim/PI.v` is not the source used by these tests or the TD project.

The external format remains signed Q16 for the default WIDTH=32, FRAC=16.
The proportional output still uses arithmetic truncation to FRAC bits.
The integral now accumulates the full `(reference-feedback)*Kp*Ki` product
with 3*FRAC fractional bits (Q48 by default), including the bits discarded
by proportional output quantization. Output quantization happens after the
high precision sum and output clamp. The anti-windup comparison also happens
before output quantization, so fractional values do not freeze integration.

The existing saved-integral clamp is +/-30. Its clamp order is retained:
save the clipped integral state, but use the unclipped current integral in
the current output calculation. The existing previous-sample saturation
freeze is retained. No PI gain, top-level reference, calibration parameter,
PWM limit or handshake latency was changed. Acceptance to output_valid is
still three clock periods, with at least four clocks between acceptances.

From a terminal with ModelSim available:

```powershell
vsim -c -do 'do E:/FPGA_2026/fpga_prj/uisrc/02_sim/pi_precision/run.do'
vsim -c -do 'do E:/FPGA_2026/fpga_prj/uisrc/02_sim/pi_precision/run_top.do'
```

The unit regression checks 2,450 transactions against an independent signed
128-bit arithmetic oracle across 32/16, 24/12, 16/11 and 16/0 formats. It
covers the measured 0.5441437 V error, one ADC-code error below a proportional
output LSB, symmetric signed integral state, positive/negative integral
clamps, extreme products, saturation freeze/recovery, input capture, result
latency, synchronous clear including a busy frame, and asynchronous reset.

The top regression uses the actual top, ADC driver, PI and PWM, with vendor
PLL/debug/PS stubs. It retains the actual 24 V target, Kp=66, Ki=655 and
calibration constants, shortens ADC reset and disables the reference ramp
only in simulation. At constant Vraw=3916 and Iraw=1687, 256 samples must
increase PI correction from 35 to 126 Q16 and PWM from 2002 to 2007 counts.
The PWM must latch the new duty, and reset must clear fractional state.

2026-10-22 validation: both simulations passed with zero errors/warnings.
The identical top regression against the saved pre-change PI fails because
the PI correction and duty remain unchanged under the constant small error.
Logs and the pre-change source are under `tmp/pi_precision_20261022/`.

These are digital arithmetic and integration tests with a constant ADC
source, not a model of power-stage stability or convergence to 24 V.
Synthesis, implementation timing, a new bitstream and physical validation
are separate steps; wider internal arithmetic requires a fresh timing check.
