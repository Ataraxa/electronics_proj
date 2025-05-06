library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fpga_toplvl_testbench is 
end entity fpga_toplvl_testbench;

architecture testbench_arch of fpga_toplvl_testbench is 

component TOP_LEVEL 
    Port(
        --- ADC interface ports
        data_in_adc : in std_logic;
        chip_select_adc : out std_logic;
        serial_clock_adc : out std_logic;

        --- DAC interface ports
        ldac : out std_logic := '0';
        chip_select : out std_logic := '1';
        serial_clock : out std_logic := '1';
        sdi : out std_logic := '0';

        --- USB interface ports
        chip_select_out : out std_logic := '1';
        mosi_out : out std_logic := '0';
        miso_out : in std_logic := 0;
        sclk_out : out std_logic := '0';
        
        --- System ports
        master_clock : in std_logic
    );
end component;

--- Signals 

begin 
    uut: TOP_LEVEL
        port map (
            -- stuff
        );

    stimulti: process 
    begin 
        -- code block
    end process;

end architecture testbench_arch;
    
