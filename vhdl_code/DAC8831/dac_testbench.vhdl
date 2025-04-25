library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dac_module_testbench is 
end entity dac_module_testbench;

architecture testbench_arch of dac_module_testbench is

component DAC_8831_MODULE
    Port(
        -- System ports
        master_clock : in std_logic;

        -- DAC ports
        ldac : out std_logic := '0';
        chip_select : out std_logic := '1';
        serial_clock : out std_logic := '1';
        sdi : out std_logic := '0';

        -- Ports from processing unit
        data_in : in std_logic_vector(15 downto 0) := (others => '0');
        data_in_valid : in std_logic := '0'
    );
end component;

--- Ports mimicking DAC_8831
signal dac_ldac : std_logic;
signal dac_cs : std_logic;
signal dac_sclk : std_logic;
signal dac_sdi : std_logic;

--- Ports mimicking inputs from processing unit
signal waveshape_data : std_logic_vector(15 downto 0) := (others => '0');
signal data_ready : std_logic := '0';

-- System signals
signal clock_12MHz : std_logic := '0';
constant clock_12MHz_period : time := 83.333 ns;
signal test_complete : boolean := false;

begin 
    uut: DAC_8831_MODULE
        port map (
            master_clock => clock_12MHz,
            ldac => dac_ldac,
            chip_select => dac_cs,
            serial_clock => dac_sclk,
            sdi => dac_sdi,
            data_in => waveshape_data,
            data_in_valid => data_ready
        );
    
    -- System clock generation 
    clock_12MHz <= not clock_12MHz after clock_12MHz_period/2 when not test_complete else '0';

    stimuli: process 
        begin 
        report("Starting simulation");
        wait for 100 ns;

        waveshape_data <= x"A5A5";
        data_ready <= '1';
        wait for 150 ns;
        data_ready <= '0';
        wait for 1.6 us;

        waveshape_data <= x"AAAA";
        data_ready <= '1';
        wait for 150 ns;
        data_ready <= '0';
        wait for 1.6 us;

        test_complete <= true;
        report("Simulation complete");
        wait;
    end process;

end architecture testbench_arch;

            
