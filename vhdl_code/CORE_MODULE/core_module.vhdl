library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity CORE_MODULE is 
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
end CORE_MODULE;

architecture Behavioral of CORE_MODULE is

    -- DBS waveform generation signals
    signal high_dbs 
    
    signal sensor_data : out std_logic_vector(15 downto 0);
    
    constant adc_cs_divider : integer := f_master_clock/f_samp;
    signal adc_cs_counter : integer range 0 to CS_divider-1 := 0;
    signal adc_cs_internal : std_logic := '1';

    -- Signals related to DAC 
    constant dac_divider : integer := 1;
    signal dac_clock_counter : integer range 0 to dac_divider-1 := 0;
    signal dac_clock_internal : std_logic := '0';
    signal dac_clock_delayed : std_logic := '0';
    signal delay_cycles : integer range 0 to 100 := 50;
    signal delay_counter : integer range 0 to 100 := 0;
    signal should_delay : std_logic := '0';

    -- Signals related to signal generation 
    type stimulation is (high, low, inter_pulse, waiting);
    signal dbs_state : stimulation;
    signal state_counter : integer range 0 to 100;
    signal high_dac : std_logic_vector(15 downto 0);
    signal low_dac : std_logic_vector(15 to 0);
    signal null_dac : std_logic_vector(15 downto 0);
    signal high_time : integer range 0 to 100;
    signal low_time : integer range 0 to 100;
    signal inter_pulse_pulse_time : integer range 0 to 100;
    signal waiting_time : integer range 0 to 100;

    CLOCK_SYNC : process(master_clock)
        begin
        if rising_edge(master_clock) then 
            if (adc_cs_counter = adc_cs_divider-1) then 
                adc_cs_internal <= not adc_cs_internal;
                adc_cs_counter <= 0;
                dac_clock_counter <= dac_clock_counter + 1;
            else 
                adc_cs_counter <= adc_cs_counter + 1;
            end if;

            if (dac_clock_counter = dac_divider - 1) then 
                dac_clock_internal <= not dac_clock_internal;
                dac_clock_counter <= 0;
                should_delay <= '1';
            end if;
        end if;
    end process CLOCK_SYNC;
    chip_select_adc <= adc_cs_internal; 

    CLOCK_DELAY : process(master_clock)
        begin 
        if rising_edge(master_clock) then 
            if (should_delay = '1') then 
                if (delay_counter = delay_cycles) then 
                    dac_clock_delayed <= '1';
                    should_delay <= '0';
                else 
                    delay_counter <= delay_counter + 1;
                end if;
            end if;
        end if;
    end process CLOCK_DELAY;

    PULSE_GEN : process(master_clock)
        begin 
        if rising_edge(dac_clock_delayed) and (dac_clock_delayed = '1') then 
            case dbs_state is 
                when high => 
                    if (state_counter = high_time) then 
                        state_counter = 0;
                        dbs_state <= inter_pulse;
                    else 
                        data_dac <= high_dac;
                        data_dac_valid <= '1';
                        state_counter <= state_counter + 1;
                    end if;

                when inter_pulse => 
                    if (state_counter = inter_pulse_time) then 
                        state_counter = 0;
                        dbs_state <= low;
                    else 
                        data_dac <= null_dac;
                        data_dac_valid <= '1';
                        state_counter <= state_counter + 1;
                    end if;

                when low => 
                    if (state_counter = low_time) then 
                        state_counter = 0;
                        dbs_state <= waiting;
                    else 
                        data_dac <= low_dac;
                        data_dac_valid <= '1';
                        state_counter <= state_counter + 1;
                    end if;

                when waiting => 
                    data_dac <= null_dac;
                    
            end case;

            state_counter <= state_counter + 1;
        end if;
    end process PULSE_GEN;
    
end architecture Behavioral;


