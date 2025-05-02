#!/bin/bash

echo "Compiling ADC module..."
ghdl -a adc_module.vhdl
ghdl -e ADC_161S_MODULE
ghdl -r ADC_161S_MODULE
echo "No error!"

echo "Compiling testbench file..." 
ghdl -a utils.vhdl 

ghdl -a testbench.vhdl
ghdl -e adc_module_testbench
ghdl -r adc_module_testbench --vcd=output_graph.vcd
echo "No error!"

gtkwave output_graph.vcd