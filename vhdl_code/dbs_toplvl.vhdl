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
end TOP_LEVEL;

architecture Structure of TOP_LEVEL is
    --- Internal connection signals
    signal chip_select_core2adc : std_logic;
    signal data_adc2core : std_logic_vector(15 downto 0);
    signal data_valid_adc2core : std_logic;

    signal data_core2dac : std_logic_vector(15 downto 0);
    signal data_valid_core2dac :std_logic;

    component CORE_MODULE
        Port(
            -- System ports
            master_clock : in std_logic;

            -- DAC ports
            data_dac : out std_logic_vector(15 downto 0) := (others => '0');
            data_dac_valid : std_logic := '0';

            -- ADC ports
            chip_select_adc : out std_logic := '1';
            data_out_adc : in std_logic_vector;
            data_out_valid_adc : in std_logic_vector;

            -- Base station ports
            chip_select_out : out std_logic := '1';
            mosi_out : out std_logic := '0';
            miso_out : in std_logic := 0;
            sclk_out : out std_logic := '0'
        );
    end component;

    component ADC_161S_MODULE
        Port(
            -- System ports
            master_clock : in std_logic; -- on-board oscillator is 12MHz
            cs_clock_external : in std_logic;

            -- ADC ports
            data_in : in std_logic;
            chip_select : out std_logic := '1';
            serial_clock : out std_logic := '1';

            -- USB module ports
            data_out : out std_logic_vector(15 downto 0) := (others => '0');
            data_out_valid_flag : out std_logic := '0'
        );
    end component;

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
            data_in : in std_logic_vector(15 downto 0);
            data_in_valid : in std_logic := '0'
        );
    end component;

    begin 

    CORE: CORE_MODULE
        port map(
            -- System ports
            master_clock => master_clock,

            -- DAC ports
            data_dac => data_core2dac
            data_dac_valid => data_valid_core2dac

            -- ADC ports
            chip_select_adc => chip_select_core2adc,
            data_out_adc => data_adc2core,
            data_out_valid_adc => data_valid_adc2core,

            -- Base station ports
            chip_select_out => chip_select_out,
            mosi_out => mosi_out,
            miso_out => miso_out,
            sclk_out => sclk_out
        );

    ADC: ADS_161S_MODULE
        port map(
            -- System ports
            master_clock => master_clock,
            cs_clock_external => chip_select_core2adc,

            -- ADC ports
            data_in => data_in_adc,
            chip_select => chip_select_adc,
            serial_clock => serial_clock_adc,

            -- Core module ports
            data_out => data_adc2core,
            data_out_valid_flag => data_valid_adc2core
        );

    DAC: DAC_8831_MODULE 
        port map(
            -- System ports
            master_clock => master_clock,

            -- DAC ports
            ldac => ldac,
            chip_select => chip_select,
            serial_clock => serial_clock,
            sdi => sdi,

            -- Ports from processing unit
            data_in => data_core2dac,
            data_in_valid => data_valid_core2dac
        );
    
    --- Additional Logic

end Structure;

    