source "E:/anlu/TD/cw/atpl/templa.tcl"
set fd [open "E:/anlu/TD/cw/atpl/cwc_ip.atpl" r]
set tmpl [read $fd]
close $fd
set parser [::tmpl_parser::tmpl_parser $tmpl]

set ComponentName        ChipWatcher_ChipWatcher_0
set bus_num              5
set depth                4096
set ram_len              35
set input_pipe_num       0
set output_pipe_num      0
set capture_ctrl_exist   1
set trig_bus_num         3
set trig_bus_din_num     3
set trig_bus_ctrl_len    12
set trig_ctrl_len        46
set trig_bus_width       { 1,1,1 };
set trig_bus_din_pos     { 0,1,2 };
set trig_bus_ctrl_pos    { 0,4,8 };
set bus_size             {  16 16 1 1 1 }
set data_enable          { probe0 probe1 probe2 probe3 probe4 }
set trig_enable          { probe2 probe3 probe4 }
set fp [open "cw/ChipWatcher_ChipWatcher_0/ChipWatcher_ChipWatcher_0_watcherInst.sv" w+]
puts $fp [eval $parser]
close $fp
