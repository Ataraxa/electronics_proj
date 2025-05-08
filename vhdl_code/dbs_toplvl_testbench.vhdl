library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.utils.all;

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
constant CLK_PERIOD   : time := 83.33 ns;
constant BAUD_PERIOD  : time := 1.667 us;

-- Interface with FTDI ports
signal spi_data : std_logic_vector(15 downto 0) := (others => '0');
signal spi_data_valid : std_logic := '0';
signal usb_input: std_logic := '1';
signal usb_input_valid : std_logic := '0';

signal clock_12MHz : std_logic := '0';
constant clock_12MHz_period : time := 83.333 ns;
signal test_complete : boolean := false;
signal expected_data : std_logic_vector(19 downto 0) := (others => '0');

-- Debug signals
signal dac_output_voltage : integer range -5 to 5;
signal dac_input_vector : std_logic_vector(15 downto 0);
signal expected_high : integer range 0 to 5 := 1;
signal expected_low : integer range -5 to 0 := -1;
signal busy_stim : std_logic;
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
            master_clock => clock_12MHz,

            -- Debug
            busy_stim => busy_stim
        );

    clock_12MHz <= not clock_12MHz after clock_12MHz_period/2 when not test_complete else '0';

    LFP_GENERATOR: process
    begin 
        while not test_complete loop 
            for i in lfp_data_array'range loop
                exit when test_complete;
                lfp_data <= lfp_data_array(i);
                wait for 500 us;
            end loop;
        end loop;
    end process LFP_GENERATOR;

    ADC_CHIP_SIMULATOR: process
    begin 
        while not test_complete loop
            wait until falling_edge(adc_cs);
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
        end loop;
    end process ADC_CHIP_SIMULATOR;
    
    DAC_CHIP_SIMULATOR: process
        variable bit_counter : integer range 0 to 15 := 15;
        procedure vector2voltage(data : std_logic_vector(15 downto 0)) is
        begin 
            report(to_hstring(data));
            dac_output_voltage <= 5 * (to_integer(unsigned(data)) - 32768) / 32768;
        end procedure;
    begin 
        wait until falling_edge(dac_chip_select); 
        while (bit_counter /= 0) loop 
            wait until rising_edge(dac_serial_clock);
            dac_input_vector(bit_counter) <= dac_sdi;
            bit_counter := bit_counter - 1;
        end loop;
        -- vector2voltage(dac_input_vector);
    end process DAC_CHIP_SIMULATOR;

    SIMULATION_CORE: process

        procedure send_uart_byte(data : std_logic_vector(7 downto 0)) is
        begin
                -- Start bit
                usb_input <= '0';
                wait for BAUD_PERIOD;
                
                -- Data bits (LSB first)
                for i in 7 downto 0 loop
                    usb_input <= data(i);
                    wait for 1 ns;
                    wait for BAUD_PERIOD - 1 ns;
                end loop;
                
                -- Stop bit
                usb_input <= '1';
                wait for BAUD_PERIOD;
        end procedure;

        procedure send_20bit(data : std_logic_vector(19 downto 0)) is
        begin
            expected_data <= data;

            -- Send as 3 bytes: [header(4)+MSB(4)] [mid byte] [LSB]
            send_uart_byte(data(19 downto 12));
            send_uart_byte(data(11 downto 4));
            send_uart_byte(data(3 downto 0) & "0000");
            wait for BAUD_PERIOD*4;  -- Inter-packet delay
        end procedure;

    begin 
        report("Starting Phase 1 - Default configuration");
        wait for 50 ms;

        report("Starting Phase 2 - Reconfigure stimulation");
        send_20bit("0000" & "1110011001100110");
        send_20bit("0001" & "0011001100110011");
        wait for 50 ms;
        send_20bit("0010" & x"0960"); -- 2400 master clock cycles, 200µs
        send_20bit("0011" & x"0258"); -- 600 master clock cycles , 50µs 
        send_20bit("0100" & x"03E8"); -- 1000 master clock cycles, 83µs
        send_20bit("0110" & x"03E8");
        wait for 50 ms;

        test_complete <= true;
        report("Simulation done.");
        wait;
    end process SIMULATION_CORE;
    
    -- VERIFY_SYNCRO_STIM: process 
    -- begin 
    --     wait until falling_edge(adc_cs);
    --     if (busy_stim = '1') then 
    --         report("Illegal sampling!");
    --     end if;
    -- end process VERIFY_SYNCRO_STIM;

    -- VERIFY_STIM_FREQUENCY: process
    -- begin 

    -- end process VERIFY_STIM_FREQUENCY;


end architecture testbench_arch;
    
