library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity core_testbench is 
end entity core_testbench;

architecture testbench_arch of core_testbench is 

component CORE_MODULE 
    Port(
        -- System ports
        master_clock : in std_logic;

        -- DAC ports
        data_dac : out std_logic_vector(15 downto 0) := (others => '0');
        data_dac_valid : out std_logic := '0';

        -- ADC ports
        chip_select_adc : out std_logic := '1';
        data_out_adc : in std_logic_vector(15 downto 0);
        data_out_valid_adc : in std_logic;

        -- FTDI interface ports
        data_received : in std_logic_vector(11 downto 0);
        data_sent : out std_logic_vector(15 downto 0)
    );
end component;

--- Ports mimicking the ADC interface module
signal chip_select_adc : std_logic := '1';
signal data_out_adc : std_logic_vector(15 downto 0) := (others => '0');
signal data_out_valid_adc : std_logic;

--- Ports mimicking the DAC interface module
signal data_dac : std_logic_vector(15 downto 0) := (others => '0');
signal data_dac_valid : std_logic := '0';

--- Ports mimicking the FTDI interface module
signal data_received : std_logic_vector(11 downto 0);
signal data_sent : std_logic_vector(15 downto 0);

--- System signals
signal clock_12MHz : std_logic := '0';
constant clock_12MHz_period : time := 83.333 ns;
signal test_complete : boolean := false;

begin 
    uut: CORE_MODULE
        port map (
            -- System ports
            master_clock => clock_12MHz,

            -- DAC ports
            data_dac => data_dac,
            data_dac_valid => data_dac_valid,

            -- ADC ports
            chip_select_adc => chip_select_adc,
            data_out_adc => data_out_adc,
            data_out_valid_adc => data_dac_valid,

            -- FTDI interface ports
            data_received => data_received,
            data_sent => data_sent
        );

    clock_12MHz <= not clock_12MHz after clock_12MHz_period/2 when not test_complete else '0';

    stimuli: process
        begin
        report("Starting simulation");
        wait for 25 ms;

        test_complete <= true;
        report("Simulationn complete");
        wait;
    end process;

end architecture testbench_arch;



