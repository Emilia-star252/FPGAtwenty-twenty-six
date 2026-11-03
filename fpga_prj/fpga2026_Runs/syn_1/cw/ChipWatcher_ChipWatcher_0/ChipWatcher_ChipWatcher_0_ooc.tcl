import_device dr1_90.db -package DR1M90GEG400
set_param flow ooc_flow on
read_verilog -file "ChipWatcher_ChipWatcher_0_watcherInst.sv"
optimize_rtl
map_macro
map
pack
report_area -file ChipWatcher_ChipWatcher_0_gate.area
export_db -mode ooc "ChipWatcher_ChipWatcher_0_ooc.db"
