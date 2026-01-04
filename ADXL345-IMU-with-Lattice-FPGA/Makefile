# Makefile for ice40HX8K FPGA
# Outputs the build files to seperate build directory.
# TOP name is required for the build option to work

# Project setup
PROJ      = top
TOP       = top
BUILD     = ./build
DEVICE    = 8k
#FOOTPRINT = ct256
PCF       = pins

# Simulation files list
SIM_FILES = moving_avg_4sample.v moving_avg_tb.v 
# Simulation file name
SIM       = top

ifeq (8k,$(DEVICE))
FOOTPRINT = ct256
else
FOOTPRINT = tq144
endif

# Files
FILES = top.v
FILES += spi_module.v spi_master.v uart_tx.v fifo.v moving_avg_4sample.v gesture_recognition.v

.PHONY: all clean prog timing verify sim


all: build prog
	

$(BUILD)/$(PROJ).json: $(FILES) | folder
	yosys -p "synth_ice40 -top $(TOP) -blif $(BUILD)/$(PROJ).blif -json $@" -ql $(BUILD)/$(PROJ).yslog $^

$(BUILD)/$(PROJ).asc: $(BUILD)/$(PROJ).json | folder
	nextpnr-ice40 --hx$(DEVICE) --package $(FOOTPRINT) --json $< --pcf $(PCF).pcf --asc $@ -ql $(BUILD)/$(PROJ).nplog

$(BUILD)/$(PROJ).bin: $(BUILD)/$(PROJ).asc | folder
	icepack $< $@

$(BUILD)/$(PROJ).out: $(FILES) | folder
	@echo 'are the used verilog files for compilation'	
	$(info $(FILES))
	iverilog -o $@ -D VCD_OUTPUT=dummy_vcd_output -D NO_ICE40_DEFAULT_ASSIGNMENTS $^ 

$(BUILD)/$(SIM)_tb: $(SIM_FILES)| folder
	iverilog -o $@ -D VCD_OUTPUT=$(SIM)_tb -D INTERACTIVE_SIM -D NO_ICE40_DEFAULT_ASSIGNMENTS $^

# vvp creates file in the main directory, couldn't make it to create file in sub directory.
$(SIM)_tb.vcd: $(BUILD)/$(SIM)_tb
	vvp $<

folder:
	mkdir -p $(BUILD)

build: $(BUILD)/$(PROJ).bin 
	./resrc_util.sh

prog: $(BUILD)/$(PROJ).bin
	@echo 'Programming in RAM Mode'
	iceprog -S $(BUILD)/$(PROJ).bin

timing: $(BUILD)/$(PROJ).asc
	icetime -tmd hx$(DEVICE) $(BUILD)/$(PROJ).asc

clean:
	rm build/*
	rm $(SIM)_tb.vcd 

verify: $(BUILD)/$(PROJ).out

sim: $(SIM)_tb.vcd
	#gtkwave --rcvar "splash_disable on" --rcvar "do_initial_zoom_fit 1" $< $(BUILD)/$(SIM).gtkw
	surfer $<
