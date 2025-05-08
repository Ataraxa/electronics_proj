library IEEE;
use IEEE.std_logic_1164.all; 

entity DAC_8831_MODULE is 
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
end DAC_8831_MODULE;

architecture Behavioral of DAC_8831_MODULE is 
    -- Signals with initial values
    signal bit_counter : integer range 0 to 16 := 0;  -- Extended to 16
    signal is_writing : std_logic := '0';
    signal data_buffer : std_logic_vector(15 downto 0) := (others => '0');
    signal data_loaded : std_logic := '0';

    -- Signals related to safety trigger
    signal buffer_time_counter : integer range 0 to 3_000 := 0;
    constant buffer_time_max : integer := 3_000;
begin 
    -- Connect serial clock directly
    serial_clock <= master_clock; 

    -- Single process for all DAC control logic
    DAC_CONTROL: process(master_clock)
    variable start_sync : std_logic_vector(1 downto 0) := "00";
    begin
        if falling_edge(master_clock) then
            -- Default assignments
            ldac <= '0';  -- Typically held low for continuous updates
            start_sync := start_sync(0) & data_in_valid;
            -- Data loading logic
            if start_sync = "01" and is_writing = '0' then
                data_buffer <= data_in;
                data_loaded <= '1';
            end if;
            
            -- Transmission state machine
            if is_writing = '1' then
                -- Actively shifting out data
                if bit_counter < 16 then
                    sdi <= data_buffer(15 - bit_counter);  -- MSB first
                    bit_counter <= bit_counter + 1;
                else
                    -- End of transmission
                    chip_select <= '1';
                    is_writing <= '0';
                    bit_counter <= 0;
                    data_loaded <= '0';
                end if;
            elsif data_loaded = '1' then
                -- Start new transmission
                buffer_time_counter <= 0;
                chip_select <= '0';
                is_writing <= '1';
                bit_counter <= 0;
                -- sdi <= data_buffer(15);  -- First bit
            end if;
            
            -- Block to reset output to 0V if stimulation time is high for too long
            if (data_buffer /= x"8000") then 
                buffer_time_counter <= buffer_time_counter + 1;
                if (buffer_time_counter = buffer_time_max) then 
                    buffer_time_counter <= 0;
                    bit_counter <= 0;
                    data_buffer <= x"8000";
                    data_loaded <= '1';
                end if;
            end if;

        end if;
    end process DAC_CONTROL;
    
end Behavioral;