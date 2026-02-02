# Clock constraints
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {sys_clk_IBUF}]

# Configuration voltage (ADD THESE)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
#set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# Pin constraints
set_property IOSTANDARD LVCMOS33 [get_ports led0]
set_property PACKAGE_PIN G20 [get_ports led0]

set_property IOSTANDARD LVCMOS33 [get_ports led1]
set_property PACKAGE_PIN G21 [get_ports led1]

set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
set_property PACKAGE_PIN M21 [get_ports sys_clk]

#create_clock -period 20.000 -name sys_clk_pin -waveform {0.000 10.000} [get_ports sys_clk]


set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property PACKAGE_PIN H7 [get_ports sys_rst_n]


set_property PACKAGE_PIN F3 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
set_property PACKAGE_PIN E3 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# LEDs

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[0]}]
set_property PACKAGE_PIN AB24 [get_ports {debug_led[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[1]}]
set_property PACKAGE_PIN AA24 [get_ports {debug_led[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[2]}]
set_property PACKAGE_PIN V24 [get_ports {debug_led[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[3]}]
set_property PACKAGE_PIN AB26 [get_ports {debug_led[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[4]}]
set_property PACKAGE_PIN Y25 [get_ports {debug_led[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[5]}]
set_property PACKAGE_PIN W25 [get_ports {debug_led[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[6]}]
set_property PACKAGE_PIN V26 [get_ports {debug_led[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[7]}]
set_property PACKAGE_PIN U25 [get_ports {debug_led[7]}]

# I2C

set_property IOSTANDARD LVCMOS33 [get_ports {i2c_sda}]
set_property PACKAGE_PIN W26 [get_ports {i2c_sda}]

set_property IOSTANDARD LVCMOS33 [get_ports {i2c_scl}]
set_property PACKAGE_PIN U26 [get_ports {i2c_scl}]

