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
        data_received : in std_logic_vector(19 downto 0);
        data_sent : out std_logic_vector(15 downto 0);
        data2consume : in std_logic
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
signal data_received : std_logic_vector(19 downto 0);
signal data_sent : std_logic_vector(15 downto 0);
signal data2consume : std_logic := '0';
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
            data_sent => data_sent,
            data2consume => data2consume
        );

    clock_12MHz <= not clock_12MHz after clock_12MHz_period/2 when not test_complete else '0';

    stimuli: process
        begin
        report("Starting simulation");

        report("Phase 1: default state");
        wait for 25 ms;
        
        report("Phase 2: reprogram base simulation parameters");
        wait until rising_edge(clock_12MHz);
        data2consume <= '1';
        data_received <= "0000" & "1110011001100110"; -- +4V
        wait until rising_edge(clock_12MHz);
        data_received <= "0001" & "0011001100110011"; -- -3V
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data_received <= "0010" & "0000101110111000"; -- 3000 cycles
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data_received <= "0011" & "0000010111011100"; -- 1500 cycles
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data_received <= "0100" & "0000010111011100"; -- 1500 cycles
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data_received <= "0101" & "000000000000" & "1010"; -- 1500 cycles
        data2consume <= '0';
        wait for 25 ms;

        report("Phase 3: testing on/off policy");
        wait until rising_edge(clock_12MHz);
        data_received <= "1111" & "0000000000000000" ; -- 1500 cycles
        wait until rising_edge(clock_12MHz);
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data2consume <= '0';
        wait for 5 ms;
        wait until rising_edge(clock_12MHz);
        data_received <= "1111" & "0000000000000001" ;
        wait until rising_edge(clock_12MHz); -- 1500 cycles
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data2consume <= '0';
        wait for 5 ms;
        wait until rising_edge(clock_12MHz);
        data_received <= "1111" & "0000000000000000" ;
        wait until rising_edge(clock_12MHz); -- 1500 cycles
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data2consume <= '0';
        wait for 5 ms;
        wait until rising_edge(clock_12MHz);
        data_received <= "1111" & "0000000000000001" ;
        wait until rising_edge(clock_12MHz); -- 1500 cycles
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data2consume <= '0';
        wait for 5 ms;
        wait until rising_edge(clock_12MHz);
        data_received <= "1111" & "0000000000000000" ;
        wait until rising_edge(clock_12MHz); -- 1500 cycles
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data2consume <= '0';
        wait for 5 ms;

        report("Phase 4: testing phase-locked policy");
        wait until rising_edge(clock_12MHz);
        data_received <= "1110" & "00000000000000" & "10" ; -- 1500 cycles
        wait until rising_edge(clock_12MHz);
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data2consume <= '0';
        wait for 7 ms;
        data_received <= "1111" & "0000000000000001" ;
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data2consume <= '0';
        wait for 7 ms;
        data_received <= "1111" & "0000000000000001" ;
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data2consume <= '0';
        wait for 5 ms;
        data_received <= "1111" & "0000000000000001" ;
        data2consume <= '1';
        wait until rising_edge(clock_12MHz);
        data2consume <= '0';
        wait for 10 ms;

        test_complete <= true;
        report("Simulation complete");
        wait;
    end process;

end architecture testbench_arch;



