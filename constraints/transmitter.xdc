create_clock -name sysclk -period 10 [get_nets design_1_i/processing_system7_0_FCLK_CLK0]
create_clock -name peripheralclk -period 31.25 [get_nets design_1_i/clk_wiz_0/clk_out1]

set_false_path -from [get_clocks sysclk] -to [get_clocks peripheralclk]
set_false_path -from [get_clocks peripheralclk] -to [get_clocks sysclk]

#set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
#set_property PACKAGE_PIN C20 [get_ports {led[1]}]

#set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
#set_property PACKAGE_PIN B20 [get_ports {led[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {tx}]
set_property PACKAGE_PIN N18 [get_ports {tx}]

set_property IOSTANDARD LVCMOS33 [get_ports {rx}]
set_property PACKAGE_PIN P19 [get_ports {rx}]

set_property IOSTANDARD LVCMOS33 [get_ports {ledn[0]}]
set_property PACKAGE_PIN N17 [get_ports {ledn[0]}]


#set_property PACKAGE_PIN H16 [get_ports clk50m]
#set_property IOSTANDARD LVCMOS33 [get_ports clk50m]

#set_false_path -from [get_clocks -of_objects [get_pins design_1_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins design_1_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT1]]
#set_false_path -from [get_clocks -of_objects [get_pins design_1_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT1]] -to [get_clocks -of_objects [get_pins design_1_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]]
