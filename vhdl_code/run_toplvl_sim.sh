#!/bin/bash

echo "Starting compilation of submodules."

echo "Compiling CORE module..."
ghdl -a --work=work CORE_MODULE/core_module.vhdl

echo "Compiling ADC module..."
ghdl -a  --work=work ADC_161S/adc_module.vhdl

echo "Compiling DAC module..."
ghdl -a  --work=work DAC_8831/dac_module.vhdl

echo "Compiling FTDI module..."
ghdl -a  --work=work FTDI_2232/ftdi_module.vhdl

echo "Compiling TOP LEVEL module..."
ghdl -a dbs_toplvl.vhdl
ghdl -e TOP_LEVEL
ghdl -r TOP_LEVEL
echo "Finished compiling modules:"

echo "Compiling utilies..."
ghdl -a --work=work ADC_161S/utils.vhdl

echo "Compiling TOP LEVEL testbench file..." 
ghdl -a --work=work dbs_toplvl_testbench.vhdl && \
ghdl -e --work=work  fpga_toplvl_testbench && \
ghdl -r --work=work  fpga_toplvl_testbench --vcd=output_graph.vcd && \
echo "No error!"