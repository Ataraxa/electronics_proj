----------------------------------------------------------------------------------
-- Company: Drakakis Lab 
-- Engineer: Alexandre Péré
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
    f_samp : integer := 3_000; 
    f_master_clock : integer := 12_000_000; -- 12 MHz on P7
    f_serial_clk : integer := 3_000_000;

    -- constant related to FTDI 2232 module
    identifier : std_logic_vector := x"00"
);
Port(
    -- System ports
    master_clock : in std_logic;

    -- DAC ports
    data_dac : out std_logic_vector(15 downto 0) := (others => '0');
    data_dac_valid : out std_logic := '0';

    -- ADC ports
    chip_select_adc : out std_logic := '1';

    -- FTDI interface ports
    data_received : in std_logic_vector(19 downto 0);
    data2consume : in std_logic
);
end CORE_MODULE;

architecture Behavioral of CORE_MODULE is
    
    -- Signals related to clock synchronisation
    signal adc_cs_master_cycles : integer range 0 to 6_000 := 2880; -- approx 2.86 kHz sampling freq.
    signal adc_cs_counter : integer range 0 to 20_000 := 0;
    signal adc_cs_internal : std_logic := '1';
    signal dac_cs_cycles : integer range 0 to 100 := 22; -- Effectively the number of ADC rising edges before trigger
    signal dac_clock_counter : integer range 0 to 100 := 0;
    signal dac_clock_internal : std_logic := '0';
    signal dac_master_clock_cycles : integer range 0 to 262_000;
    
    -- Signals related to DAC 
    -- signal is_stimulating : std_logic := '0';
    signal delay_cycles : integer range 0 to 100 := 50;
    signal delay_counter : integer range 0 to 100 := 0;
    signal should_delay : std_logic := '0';
    signal should_start : std_logic := '1';
    signal should_recalculate : std_logic := '1';

    -- Signals related to signal generation 
    type stimulation is (high, low, inter_pulse, waiting, recovery);
    signal dbs_state : stimulation;
    signal state_counter : integer range 0 to 7000;
    signal high_dac : std_logic_vector(15 downto 0) := "1001100110011001"; -- +1V
    signal low_dac : std_logic_vector(15 downto 0) := "0110011001100110";
    signal null_dac : std_logic_vector(15 downto 0) := "1000000000000000";
    signal high_time : integer range 0 to 7000 := 1200; -- 100 µs
    signal low_time : integer range 0 to 7000 := 1200; -- 100 µs
    signal inter_pulse_time : integer range 0 to 7000 := 240; -- 20 µs
    signal recovery_time : integer range 0 to 7000 := 240;
    signal stim_f : integer range 1 to 250 := 130; -- in Hertz
    -- signal debug_state : integer range 0 to 10;

    -- Signal related to input data reading and reprogrammation
    signal reset : std_logic := '0';
    
    -- Signal related to control policy
    type control_policy is (phase_locked, on_off, amplitude_prop);
    signal selected_policy : control_policy := on_off;
    signal is_phase_delaying : std_logic := '0';
    signal target_state : std_logic := '1'; -- 2 is should update high, 1 is ignore, 0 is update low
    signal on_off_state : std_logic := '1';
    signal phase_delay_counter : integer range 0 to 10_000_000 := 0;
    signal phase_delay_cycles : integer range 0 to 10_000_000 := 10_000; 
    signal trigger_time_counter : integer  range 0 to 10_000_00 := 0;
    signal trigger_time_cycles : integer range 0 to 10_000_000 := 10_000;

    begin 

    CLOCK_SYNC : process(master_clock)
        begin
        if rising_edge(master_clock) then 

            if (reset = '1') then 
                adc_cs_counter <= 0;
                dac_clock_counter <= 0;
                delay_counter <= 0;

                adc_cs_internal <= '0';
                dac_clock_internal <= '0';
                should_delay <= '0';
            end if;
            --- Generate the ADC clock by a clock divider
            if (adc_cs_counter = adc_cs_master_cycles) then 
                if (adc_cs_internal = '1') then 
                    -- If ADC clock on falling edge, increment DAC clock counter
                    dac_clock_counter <= dac_clock_counter + 1;
                end if;
                adc_cs_internal <= not adc_cs_internal;
                adc_cs_counter <= 0;
            else 
                adc_cs_counter <= adc_cs_counter + 2;
            end if;

            if (dac_clock_counter = dac_cs_cycles) then 
                dac_clock_internal <= not dac_clock_internal;
                dac_clock_counter <= 0;
                should_delay <= '1';
                delay_counter <= delay_counter + 1;
            else
                should_start <= '0';
            end if;

            if (should_delay = '1') then 
                if (delay_counter = delay_cycles) then 
                    delay_counter <= 0;
                    should_start <= '1';
                    should_delay <= '0';
                else 
                    delay_counter <= delay_counter + 1;
                end if;
            end if;
        end if;
    end process CLOCK_SYNC;
    chip_select_adc <= adc_cs_internal; 

    PULSE_GEN : process(master_clock)
    variable is_stimulating : std_logic := '0';
    begin 
        if rising_edge(master_clock) then
            if (reset = '1') then
                report("gonna reset!");
                dbs_state <= waiting;
                state_counter <= 0;
                is_stimulating := '0';
            elsif (should_start = '1') then 
                is_stimulating := '1';
                dbs_state <= high;
                state_counter <= 0;
            end if;

            if (is_stimulating = '1') and (on_off_state = '1') then 
                case dbs_state is 
                    when high => 
                        if (state_counter = high_time) then
                            state_counter <= 0;
                            dbs_state <= inter_pulse;
                        else 
                            data_dac <= high_dac;
                            data_dac_valid <= '1';
                            -- if (state_counter + 1 > )
                            -- report(integer'image(high_time));
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
                            dbs_state <= recovery;
                        else 
                            data_dac <= low_dac;
                            data_dac_valid <= '1';
                            state_counter <= state_counter + 1;
                        end if;

                    when recovery => 
                        if (state_counter = recovery_time) then 
                            state_counter <= 0;
                            dbs_state <= waiting;
                            is_stimulating := '0';
                        else 
                            data_dac <= null_dac;
                            data_dac_valid <= '1';
                            state_counter <= state_counter + 1;
                        end if;

                    when waiting =>
                        dbs_state <= high;
                end case;
            else
                data_dac <= null_dac;
                dbs_state <= waiting;
            end if;
        end if;
    end process PULSE_GEN;

    REPROG : process(master_clock)
    variable header : std_logic_vector(3 downto 0);
    variable message : std_logic_vector(15 downto 0);
    variable total_stim_period : integer range 1 to 12_000; -- max stim period is 1 ms, including recovery 
    begin 
        if rising_edge(master_clock) then 
            if (data2consume = '1') then 
                reset <= '1';
                header := data_received(19 downto 16);
                message := data_received(15 downto 0);
                
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
                    when "0110" => recovery_time <= to_integer(unsigned(message));

                    -- Control policy, starting with a 1
                    when "1111" => -- toggle on/off state
                        if (message = "0000000000000000") then 
                            target_state <= '0';
                        else
                            target_state <= '1';
                        end if;

                    when "1110" => 
                        case to_integer(unsigned(message)) is
                            when 1 => selected_policy <= on_off;
                            when 2 => selected_policy <= phase_locked;
                            when 3 => selected_policy <= amplitude_prop;
                            when others => null;
                        end case;

                    when others => null;  -- Undefined headers do nothing
                end case;

                if (header /= "1111") and (header /= "1110") then -- need to recalculate all timings
                    should_recalculate <= '1';
                end if;
                
                -- data2consume <= '0';  -- Clear the consume flag
            else 
                -- if phase_locked policy, need to reset the trigger when no event detected
                if (selected_policy = phase_locked) then 
                    target_state <= '0';
                end if;

                reset <= '0';
            end if;

            if (should_recalculate = '1') then 
                report("Gonna recalculate timings!");
                total_stim_period := high_time + inter_pulse_time + low_time + recovery_time;
                adc_cs_master_cycles <= total_stim_period;
                dac_cs_cycles <= f_master_clock / (stim_f * total_stim_period);
                should_recalculate <= '0';
            end if;
        end if;
    end process REPROG;
    
    ON_OFF_CONTROL: process(master_clock, target_state)
    begin 
        if rising_edge(target_state) then 
            -- Rising edge detected
            case selected_policy is
                when on_off =>
                    on_off_state <= '1';
                
                when phase_locked =>
                    is_phase_delaying <= '1';
                    on_off_state <= '0';
                    phase_delay_counter <= 0;  -- Reset counter on trigger

                when others => null;
            end case; 
 
            -- elsif (target_state = '0') then
            --     -- Falling edge detected
            --     if (selected_policy = on_off) then 
            --         on_off_state <= '0';
            --     end if;
            -- end if;
        elsif falling_edge(target_state) then
            if (selected_policy = on_off) then 
                on_off_state <= '0';
            end if;
        end if;

        if rising_edge(master_clock) then
            -- Synchronize external trigger to clock domain
            -- if (data2consume = '1') then   


            -- Delay logic (phase_locked policy)
            if (is_phase_delaying = '1') then 
                if (phase_delay_counter = phase_delay_cycles) then 
                    on_off_state <= '1';
                    is_phase_delaying <= '0';
                    phase_delay_counter <= 0;
                else 
                    phase_delay_counter <= phase_delay_counter + 1;
                end if;
            elsif (on_off_state = '1') and (selected_policy = phase_locked) then
                if (trigger_time_counter = trigger_time_cycles) then 
                    on_off_state <= '0';
                    trigger_time_counter <= 0;
                else 
                    trigger_time_counter <= trigger_time_counter + 1;
                end if;
            end if;
        end if;
    end process ON_OFF_CONTROL;            

end architecture Behavioral;


