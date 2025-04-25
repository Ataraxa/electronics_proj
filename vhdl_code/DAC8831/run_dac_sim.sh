#!/bin/bash

echo "Compiling DAC module..."
ghdl -a dac_module.vhdl
ghdl -e DAC_8831_MODULE
ghdl -r DAC_8831_MODULE
echo "No error!"

echo "Compiling testbench file..." 
# ghdl -a utils.vhdl 
ghdl -a dac_testbench.vhdl
ghdl -e dac_module_testbench
ghdl -r dac_module_testbench --vcd=output_graph.vcd
echo "No error!"

# gtkwave output_graph.vcd