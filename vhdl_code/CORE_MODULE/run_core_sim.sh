#!/bin/bash

echo "Compiling module..."
ghdl -a core_module.vhdl
ghdl -e CORE_MODULE
ghdl -r CORE_MODULE

echo "Compiling testbench..." 
ghdl -a core_testbench.vhdl
ghdl -e core_testbench
ghdl -r core_testbench --vcd=output_graph.vcd

# gtkwave output_graph.vcd