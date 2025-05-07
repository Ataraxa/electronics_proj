----------------------------------------------------------------------------------
-- Code to read from the ADC161S626 IC
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ADC_161S_MODULE is 
Generic(
    -- can decalre generic variables here
    f_master_clock : integer := 12_000_000; -- 12 MHz on P7
    f_serial_clk : integer := 3_000_000
);
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
end ADC_161S_MODULE;

architecture Behavioral of ADC_161S_MODULE is 
    -- State of ADC
    type machine is (receiving, waiting); 
    signal fpga_state : machine;

    -- ADS signals
    signal data_buffer : std_logic_vector(15 downto 0) := (others => '0');

    constant sclk_divider : integer := f_master_clock/f_serial_clk;
    signal sclk_counter : integer range 0 to sclk_divider-1 := 0;
    signal sclk_internal : std_logic := '1'; 

    -- Input bit counter
    signal data_in_counter : integer range 0 to 17 := 0;
    signal is_receiving : std_logic := '0';
    
    begin -- Begin description of ADC behaviour

    -- Generates chip_select clock
    -- CS_CLOCK : process(master_clock) 
    --     begin 
    --     if rising_edge(master_clock) then 
    --         if (CS_counter = CS_divider-1) then 
    --             CS_clock_internal <= not CS_clock_internal;
    --             CS_counter <= 0; --TODO: change this
    --         else 
    --             CS_counter <= CS_counter + 1;
    --         end if;
    --     end if;                    
    -- end process CS_CLOCK;
    -- chip_select <= CS_clock_internal;
    chip_select <= cs_clock_external;

    SER_CLOCK : process(master_clock)
        begin
        if (cs_clock_external = '1') then 
            -- do nothing 
            sclk_internal <= '1';
        elsif rising_edge(master_clock) then
            if (sclk_counter = sclk_divider-1) then
                sclk_internal <= not sclk_internal;
                sclk_counter <= 0;
            else 
            sclk_counter <= sclk_counter + 1;
            end if;
        end if;
    end process SER_CLOCK;
    serial_clock <= sclk_internal;

    ADC_PROCESS : process(sclk_internal)
    variable sync_start : std_logic_vector(1 downto 0) := "ZZ";
    begin 
    if rising_edge(sclk_internal) then 
        data_out_valid_flag <= '0';
        sync_start := sync_start(1) & data_in;

        if data_in_counter = 0 and sync_start = "Z0" then
            is_receiving <= '1';
            data_in_counter <= data_in_counter + 1;
        elsif is_receiving = '1' then 
            if data_in_counter < 17 then 
                data_buffer <= data_buffer (14 downto 0) & data_in;
                data_in_counter <= data_in_counter + 1;
            else
                data_out <= data_buffer;
                data_out_valid_flag <= '1';
                data_in_counter <= 0;
                is_receiving <= '0';
            end if; 
        end if;
    end if;
            
    end process ADC_PROCESS;
    
end Behavioral;
