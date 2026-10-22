## =============================================================================
## XDC Constraints File: Digilent Arty A7-100T (XC7A100TCSG324-1)
## Target Design: 5-Stage Pipelined RV64I Processor Core
## =============================================================================

## Clock Signal (100 MHz onboard oscillator)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## Active-High Synchronous Reset (Push Button btn[0])
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { rst }];

## Status / Debug Output Signals (User LEDs)
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { debug_stall }];
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { debug_flush }];
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { debug_pc[2] }];
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { debug_pc[3] }];
