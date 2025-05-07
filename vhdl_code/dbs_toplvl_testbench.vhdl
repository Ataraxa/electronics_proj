library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fpga_toplvl_testbench is 
end entity fpga_toplvl_testbench;

architecture testbench_arch of fpga_toplvl_testbench is 

------- ADC SECTION ----------------------------------------------------
-- Ports
signal adc_data : std_logic := '0';
signal adc_cs : std_logic := '0';
signal adc_sclk : std_logic := '0';
-- Testbench signals
signal lfp_data : std_logic_vector(15 downto 0);
type value_array is array (natural range <>) of std_logic_vector(15 downto 0);
constant lfp_data_array : value_array := (
    x"ABC1",  -- Value 1
    x"1234",  -- Value 2
    x"5678",  -- Value 3
    x"9ABC",  -- Value 4
    x"FFFF"   -- Value 5 (example last value)
);

-- Interface with DAC
signal dac_ldac : std_logic := '0';
signal dac_chip_select : std_logic := '1';
signal dac_serial_clock : std_logic := '1';
signal dac_sdi : std_logic := '0'; 

-- Interface with FTDI ports
signal spi_data : std_logic_vector(15 downto 0) := (others => '0');
signal spi_data_valid : std_logic := '0';
signal usb_input: std_logic;
signal usb_input_valid : std_logic := '0';

signal clock_12MHz : std_logic := '0';
constant clock_12MHz_period : time := 83.333 ns;
signal test_complete : boolean := false;
begin 
    uut: entity work.TOP_LEVEL
        port map (
            -- ADC ports
            data_in_adc => adc_data,
            chip_select_adc => adc_cs,
            serial_clock_adc => adc_sclk,

            -- DAC ports
            ldac => dac_ldac,
            chip_select_dac => dac_chip_select,
            serial_clock_dac => dac_serial_clock,
            sdi => dac_sdi,

            -- FPGA output ports
            spi_data => spi_data,
            spi_data_valid => spi_data_valid,

            -- FPGA input ports
            usb_input => usb_input,
            usb_input_valid => usb_input_valid,

            -- System ports
            master_clock => clock_12MHz
        );

    clock_12MHz <= not clock_12MHz after clock_12MHz_period/2 when not test_complete else '0';

    LFP_GENERATOR: process
        begin 
        for i in lfp_data_array'range loop
            lfp_data <= lfp_data_array(i);
            wait for 500 us;
        end loop;
        wait for 30 ms;
        test_complete <= true;
        report("Simulation complete!");
        wait;
    end process LFP_GENERATOR;

    ADC_CHIP_SIMULATOR: process
    begin 
        wait until falling_edge(adc_cs);
        -- report("ADC conversion initiated!");

        wait until falling_edge(adc_sclk);
        adc_data <= 'Z';
        wait until falling_edge(adc_sclk);
        adc_data <= '0';
        for i in 15 downto 0 loop
            wait until falling_edge(adc_sclk);
            adc_data <= lfp_data(i);
        end loop;
        wait until falling_edge(adc_sclk);
        adc_data <= 'Z';

        -- report("ADC conversion done!");
    end process ADC_CHIP_SIMULATOR;

end architecture testbench_arch;
    
