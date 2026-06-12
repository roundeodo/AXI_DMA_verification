set UVM_src      /esat/micas-data/software/Mentor/questasim_2022.4/verilog_src/uvm-1.2/src

##--- dump waveform and debug mode ---##
if [file exists work] { vdel -all }
vlib work
vmap work work

## vlog -sv12compat -mfcu +incdir+$UVM_src -L mtiUvm -f flist.f
## vlog -sv12compat -mfcu +incdir+$UVM_src $UVM_src/uvm_pkg.sv -f flist.f
vlog -sv12compat -mfcu +define+UVM_NO_DPI +incdir+$UVM_src $UVM_src/uvm_pkg.sv -f flist.f
vsim -c +nowarnTSCALE -voptargs=+acc -classdebug -L ./work -l load.log top_tb
radix hex
add log -r /top_tb/*
if [file exists wave.do] { do ./wave.do }
run -all