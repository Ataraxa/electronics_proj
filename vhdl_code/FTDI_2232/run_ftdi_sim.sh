#!/bin/bash

echo "Compiling FTDI module..."
ghdl -a ftdi_module.vhdl
ghdl -e FTDI_2232_RX
ghdl -r FTDI_2232_RX
echo "No error!"

# echo "Compiling utilities file..."
# ghdl -a utils.vhdl && \ 
# echo "No error!"

echo "Compiling FTDI testbench file..." 
ghdl -a ftdi_testbench.vhdl && \
ghdl -e ftdi_module_testbench && \
ghdl -r ftdi_module_testbench --vcd=output_graph.vcd && \
echo "No error!"

# gtkwave output_graph.vcd