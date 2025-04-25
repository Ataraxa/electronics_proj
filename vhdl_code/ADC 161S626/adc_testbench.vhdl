library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.utils.all;

entity adc_module_testbench is 
end entity adc_module_testbench;

architecture testbench_arch of adc_module_testbench is 

component ADC_161S_MODULE
    Port(
        -- System ports
        master_clock : in std_logic; -- on-board oscillator is 12MHz

        -- ADC ports
        data_in : in std_logic;
        chip_select : out std_logic;
        serial_clock : out std_logic;

        -- USB module ports
        data_out : out std_logic_vector(15 downto 0);
        data_out_valid_flag : out std_logic
    );
end component;

--- Ports mimicking ADS_161S
signal adc_data_out : std_logic := 'Z';
signal adc_chip_select : std_logic := '0';
signal adc_serial_clock : std_logic := '1';

--- Ports to check output of FPGA
signal usb_data_in : std_logic_vector(15 downto 0) := (others => '0');
signal usb_data_flag : std_logic := '0';

-- System signals
signal clock_12MHz : std_logic := '0';
constant clock_12MHz_period : time := 83.333 ns;
signal test_complete : boolean := false;
signal expected_data : std_logic_vector(15 downto 0) := (others => '0');

begin 
    uut: ADC_161S_MODULE
        port map (
            master_clock => clock_12MHz,
            data_in => adc_data_out,
            chip_select => adc_chip_select,
            serial_clock => adc_serial_clock,
            data_out => usb_data_in,
            data_out_valid_flag => usb_data_flag 
        );

    -- System clock generation 
    clock_12MHz <= not clock_12MHz after clock_12MHz_period/2 when not test_complete else '0';

    stimuli: process 
        procedure send_adc_word(data : in std_logic_vector(15 downto 0)) is 
        begin 
            wait until falling_edge(adc_chip_select);
            report("Starting new ADC conversion");
            expected_data <= data;

            wait until falling_edge(adc_serial_clock);
            adc_data_out <= 'Z';

            wait until falling_edge(adc_serial_clock);
            adc_data_out <= '0';

            for i in 15 downto 0 loop
                wait until falling_edge(adc_serial_clock);
                adc_data_out <= data(i);
            end loop;

            wait until falling_edge(adc_serial_clock);
            adc_data_out <= 'Z';
        end procedure;

    begin
        report("Starting simulation ");
        wait for 100 ns;

        send_adc_word(x"A5A5");

        send_adc_word(x"AAAA");

        wait until rising_edge(adc_chip_select);
        wait for 1 us;

        test_complete <= true;
        report("Simulation complete");
        wait;
    end process;

    verify: process
    begin 
        wait until rising_edge(usb_data_flag);
        report to_hstring(expected_data);
        report to_hstring(usb_data_in);

        assert usb_data_in = expected_data
            report "Data mismatch! Expected"
            severity Error;

        report "Data verified!";
    end process;
end architecture testbench_arch;