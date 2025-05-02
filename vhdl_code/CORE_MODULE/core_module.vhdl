----------------------------------------------------------------------------------
-- Company: Drakakis Lab 
-- Engineer: 
-- 
-- Create Date:    14:03:41 12/04/2020 
-- Design Name: 
-- Module Name:   
-- Project Name: 	
-- Target Devices: 
-- Tool versions:
-- Description: 
-- 
-- Implements the control logic of the FPGA. The main features are:
--  - generating the ADC clock from the master clock. Frequency is derived
--    from the total pulse width and stimulatio frequency, which is programmed
--    into the FPGA by the external base station.
--  - generating the stim. pulses, synchronised with the ADC clock plus some
--    delay. The frequency of the stimulation pulses is a integer divider of
--    the ADC clock (this can be 1). The delay is solely determined by the
--    conversion time of the ADC.
--  - being reprogrammable by the external base station. Whenever an input
--    message is received, it is decoded and used to reprogram the stim. pulses
--    or to modulate the DAC output. This modulation depends on the adaptive
--    policy chosen (can be updated by external reprogramming). 
-- 
-- Dependencies: 
-- N/A
--
-- Revision: 
-- Revision 0.1
-- Additional Comments: 
-- N/A
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity CORE_MODULE is 
Generic(
    -- can decalre generic variables here
    f_samp : integer := 2_000; 
    f_master_clock : integer := 12_000_000; -- 12 MHz on P7
    f_serial_clk : integer := 3_000_000
);
Port(
    -- System ports
    master_clock : in std_logic;

    -- DAC ports
    data_dac : out std_logic_vector(15 downto 0) := (others => '0');
    data_dac_valid : out std_logic := '0';

    -- ADC ports
    chip_select_adc : out std_logic := '1';
    data_out_adc : in std_logic_vector(15 downto 0) := (others => '0');
    data_out_valid_adc : in std_logic := '0';

    -- FTDI interface ports
    data_received : in std_logic_vector(19 downto 0);
    data_sent : out std_logic_vector(15 downto 0)

    -- -- Base station ports
    -- chip_select_out : out std_logic := '1';
    -- mosi_out : out std_logic := '0';
    -- miso_out : in std_logic := 0;
    -- sclk_out : out std_logic := '0'
);
end CORE_MODULE;

architecture Behavioral of CORE_MODULE is
    
    signal sensor_data : std_logic_vector(15 downto 0);
    
    constant adc_cs_divider : integer := f_master_clock/f_samp;
    signal adc_cs_counter : integer range 0 to adc_cs_divider := 0;
    signal adc_cs_internal : std_logic := '1';

    -- Signals related to DAC 
    constant dac_divider : integer := 1; -- Effectively the number of ADC rising edges before trigger
    signal dac_clock_counter : integer range 0 to dac_divider+1 := 0;
    signal dac_clock_internal : std_logic := '0';
    signal is_stimulating : std_logic := '0';
    signal delay_cycles : integer range 0 to 100 := 50;
    signal delay_counter : integer range 0 to 100 := 0;
    signal should_delay : std_logic := '0';

    -- Signals related to signal generation 
    type stimulation is (high, low, inter_pulse, waiting, finished);
    signal dbs_state : stimulation;
    signal state_counter : integer range 0 to 150;
    signal high_dac : std_logic_vector(15 downto 0) := "1001100110011001"; -- +1V
    signal low_dac : std_logic_vector(15 downto 0) := "0110011001100110";
    signal null_dac : std_logic_vector(15 downto 0) := "1000000000000000";
    signal high_time : integer range 0 to 7000 := 50;
    signal low_time : integer range 0 to 7000 := 50;
    signal inter_pulse_time : integer range 0 to 7000 := 50;
    signal waiting_time : integer range 0 to 100 := 99;

    -- Signal related to input data reading and reprogrammation
    signal data2consume : std_logic := '0';
    signal header : std_logic_vector(3 downto 0);
    signal message : std_logic_vector(15 downto 0);
    
    -- Signal related to control policy
    type control_policy is (phase_locked, on_off, amplitude_prop);
    signal selected_policy : control_policy := on_off;
    type policy_state is (is_on, is_off, delaying);
    signal control_state : policy_state := is_on;
    signal multipurpose_trigger : std_logic := '0'; -- 2 is should update high, 1 is ignore, 0 is update low
    signal on_off_state : std_logic := '1';
    signal phase_delay_counter : integer range 0 to 10_000_000 := 0;
    signal phase_delay_cycles : integer range 0 to 10_000_000 := 10_000; 
    signal trigger_time_counter : integer  range 0 to 10_000_00 := 0;
    signal trigger_time_cycles : integer range 0 to 10_000_000 := 10_000;

    begin 

    CLOCK_SYNC : process(master_clock)
        begin
        if rising_edge(master_clock) then 

            --- Generate the ADC clock by a clock divider
            if (adc_cs_counter = adc_cs_divider-1) then 
                if (adc_cs_internal = '0') then 
                    -- If ADC clock on rising edge, increment DAC clock counter
                    dac_clock_counter <= dac_clock_counter + 1;
                end if;
                adc_cs_internal <= not adc_cs_internal;
                adc_cs_counter <= 0;
            else 
                adc_cs_counter <= adc_cs_counter + 1;
            end if;

            if (dac_clock_counter = dac_divider) then 
                dac_clock_internal <= not dac_clock_internal;
                dac_clock_counter <= 0;
                should_delay <= '1';
                delay_counter <= delay_counter + 1;
            end if;

            if (should_delay = '1') then 
                if (delay_counter = delay_cycles) then 
                    delay_counter <= 0;
                    is_stimulating <= '1';
                else 
                    delay_counter <= delay_counter + 1;
                end if;
            end if;

            if (dbs_state = finished) and (is_stimulating = '1') then 
                is_stimulating <= '0';
            end if;
        end if;
    end process CLOCK_SYNC;
    chip_select_adc <= adc_cs_internal; 

    PULSE_GEN : process(master_clock)
        begin 
        if rising_edge(master_clock) then
            if (is_stimulating = '1') and (on_off_state = '1') then 
                case dbs_state is 
                    when high => 
                        if (state_counter = high_time) then
                            state_counter <= 0;
                            dbs_state <= inter_pulse;
                        else 
                            data_dac <= high_dac;
                            data_dac_valid <= '1';
                            state_counter <= state_counter + 1;
                        end if;

                    when inter_pulse => 
                        if (state_counter > 45) then 
                        end if;

                        if (state_counter = inter_pulse_time) then 
                            state_counter <= 0;
                            dbs_state <= low;
                        else 
                            data_dac <= null_dac;
                            data_dac_valid <= '1';
                            state_counter <= state_counter + 1;
                        end if;

                    when low => 
                        if (state_counter = low_time) then 
                            state_counter <= 0;
                            dbs_state <= finished;
                        else 
                            data_dac <= low_dac;
                            data_dac_valid <= '1';
                            state_counter <= state_counter + 1;
                        end if;

                    when finished => 
                        data_dac <= null_dac;

                    when waiting =>
                        dbs_state <= high;

                end case;
            else
                dbs_state <= waiting;
            end if;
        end if;
    end process PULSE_GEN;

    REPROG : process(master_clock)
    begin 
        if rising_edge(master_clock) then 
            if (data2consume = '1') then 
                header <= data_received(19 downto 16);
                message <= data_received(15 downto 0);
                
                -- Use header to select which variable to update
                case header is
                    -- Reprogam amplitude
                    when "0000" => high_dac <= message; -- Extend 8-bit to 16-bit
                    when "0001" => low_dac <= message;

                    -- Reprogram timing
                    when "0010" => high_time <= to_integer(unsigned(message));
                    when "0011" => low_time <= to_integer(unsigned(message));
                    when "0100" => inter_pulse_time <= to_integer(unsigned(message));
                    when "0101" => delay_cycles <= to_integer(unsigned(message));

                    -- Control policy, starting with a 1
                    when "1111" => -- toggle on/off state
                        if (to_integer(unsigned(message)) = 0) then 
                            multipurpose_trigger <= 0;
                        else
                            multipurpose_trigger <= 2;
                        end if;

                    when others => null;  -- Undefined headers do nothing
                end case;
                
                data2consume <= '0';  -- Clear the consume flag
            end if;
        end if;
    end process REPROG;

    ON_OFF_CONTROL: process(master_clock, multipurpose_trigger)
    begin 
        if rising_edge(master_clock) then 
            if rising_edge(multipurpose_trigger) then 
                case selected_policy is
                    when on_off =>
                        control_state <= is_on;
                        on_off_state <= '1';
                    
                    when phase_locked =>
                        control_state <= delaying;
                        phase_delay_counter <= phase_delay_counter + 1;

                    when others => null;
                end case;

            elsif falling_edge(multipurpose_trigger) then
                if (selected_policy = on_off) then 
                    control_state <= is_off;
                    on_off_state <= '0';
                end if;

            else 
                if (state = delaying) then 
                    if (phase_delay_counter = phase_delay_cycles) then 
                        control_policy <= is_on;
                        phase_delay_counter <= 0;
                    else 
                        phase_delay_counter <= phase_delay_counter + 1;
                    end if;
                end if;

                if (state = is_on) and (selected_policy = phase_locked) then
                    if (trigger_time_counter = trigger_time_cycles) then 
                        control_policy <= is_off;
                        trigger_time_counter <= 0;
                    else 
                        trigger_time_counter <= trigger_time_counter + 1;
                    end if;
                end if; 
            end if;
            
            case control_state is
                when is_on => on_off_state <= '1';
                when is_off => on_off_state <= '0'; 
                when delaying => on_off_state <= '0';
            end case; 
        end if;
    end process ON_OFF_CONTROL;            

end architecture Behavioral;


