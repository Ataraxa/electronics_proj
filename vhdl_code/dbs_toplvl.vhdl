library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
entity TOP_LEVEL is 
    Port(
        --- ADC interface ports
        data_in_adc : in std_logic;
        chip_select_adc : out std_logic;
        serial_clock_adc : out std_logic;

        --- DAC interface ports
        ldac : out std_logic := '0';
        chip_select_dac : out std_logic := '1';
        serial_clock_dac : out std_logic := '1';
        sdi : out std_logic := '0';

        --- FTDI interface ports
        spi_data : out std_logic_vector(15 downto 0) := (others => '0');
        spi_data_valid : out std_logic := '0';
        usb_input : in std_logic;
        usb_input_valid : in std_logic := '0';
        
        --- System ports
        master_clock : in std_logic
    );
end TOP_LEVEL;

architecture Structure of TOP_LEVEL is
    --- Internal connection signals
    signal chip_select_core2adc : std_logic;
    signal data_adc2core : std_logic_vector(15 downto 0);
    signal data_valid_adc2core : std_logic;

    signal data_core2dac : std_logic_vector(15 downto 0);
    signal data_valid_core2dac :std_logic;

    signal data_ftdi2core : std_logic_vector(19 downto 0);
    signal data_valid_ftdi2core : std_logic;

    begin 

    CORE: entity work.CORE_MODULE
        port map(
            -- System ports
            master_clock => master_clock,

            -- DAC ports
            data_dac => data_core2dac,
            data_dac_valid => data_valid_core2dac,

            -- ADC ports
            chip_select_adc => chip_select_core2adc,

            -- Base station ports
            data_received => data_ftdi2core,
            data2consume => data_valid_ftdi2core
        );

    ADC: entity work.ADC_161S_MODULE
        port map(
            -- System ports
            master_clock => master_clock,
            cs_clock_external => chip_select_core2adc,

            -- ADC ports
            data_in => data_in_adc,
            chip_select => chip_select_adc,
            serial_clock => serial_clock_adc,

            -- Output ports
            data_out => spi_data,
            data_out_valid_flag => spi_data_valid
        );

    DAC: entity work.DAC_8831_MODULE 
        port map(
            -- System ports
            master_clock => master_clock,

            -- DAC ports
            ldac => ldac,
            chip_select => chip_select_dac,
            serial_clock => serial_clock_dac,
            sdi => sdi,

            -- Ports from processing unit
            data_in => data_core2dac,
            data_in_valid => data_valid_core2dac
        );
    
        FTDI: entity work.FTDI_2232_RX
            port map(
                -- System ports
                master_clock => master_clock,

                -- Receiving ports from USB module
                FTDI_RX => usb_input,
                FTDI_CTS => usb_input_valid,

                -- Ports to core logic module
                data_received => data_ftdi2core,
                data_valid => data_valid_ftdi2core
            );

    --- Additional Logic

end Structure;

    