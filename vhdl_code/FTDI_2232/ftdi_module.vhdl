library IEEE;
use IEEE.std_logic_1164.all;

entity FTDI_2232_RX is 
    Port(
        -- System ports
        master_clock : in std_logic;

        -- Receiving ports from USB module
        FTDI_RX : in std_logic;
        FTDI_CTS : in std_logic;

        -- Ports to core logic module
        data_received : out std_logic_vector(19 downto 0) := (others => '0');
        data_valid : out std_logic := '0'
    );
end FTDI_2232_RX;

architecture Behaviour of FTDI_2232_RX is

-- Constants for UART (match FTDI configuration)
constant BAUD_RATE   : integer := 600_000;  -- Must match FTDI baud rate
constant CLK_FREQ    : integer := 12_000_000;  -- Your FPGA clock frequency
constant BAUD_PERIOD : integer := CLK_FREQ / BAUD_RATE;

-- UART Receiver Signals
type machine is (waiting_start, waiting_end, receiving);
signal rx_status : machine := waiting_start;
-- signal uart_rx_data_reg      : std_logic_vector(7 downto 0);
signal uart_rx_data_valid : std_logic := '0';
signal uart_rx_counter   : integer range 0 to BAUD_PERIOD-1 :=  BAUD_PERIOD/2;
signal uart_rx_bit_index : integer range 0 to 8 := 7;
signal uart_rx_reg       : std_logic_vector(7 downto 0) := (others => '0');
signal uart_rx_sync      : std_logic_vector(1 downto 0) := "11";
signal buffer_counter    : integer range 0 to 3 := 3;

-- Signals to synchronise processes
signal baud_flag : std_logic := '0';
signal should_start : std_logic := '0';

begin 

    BAUD_CLOCK: process(master_clock)
    begin 
        if rising_edge(master_clock) then
            uart_rx_sync <= uart_rx_sync(0) & FTDI_RX;

            -- Initiate RX state
            if (uart_rx_sync = "10") and (rx_status = waiting_start) then
                should_start <= '1';
                uart_rx_counter  <= BAUD_PERIOD/2;  -- Sample at mid-bit
            end if;

            -- Reset should_start flag 
            if (rx_status = receiving) then 
                should_start <= '0';
            end if;
            
            -- Generate Baud clock
            if (uart_rx_counter = 0) then
                baud_flag <= '1';
                uart_rx_counter <= BAUD_PERIOD - 1;
            else 
                baud_flag <= '0';
                uart_rx_counter <= uart_rx_counter - 1;
            end if;
        end if;
    end process;

    -- UART Receiver Process
    UART_RX_MAIN : process(baud_flag)
    begin
        if rising_edge(baud_flag) then
            -- Default assignments
            uart_rx_data_valid <= '0';

            case rx_status is 
                when waiting_start =>
                    -- Check for start bit (falling edge)
                    if (should_start = '1') then 
                        rx_status <= receiving;
                    end if;

                when receiving => 
                    if (uart_rx_bit_index = 0) then
                        -- Stop receiving
                        uart_rx_reg(uart_rx_bit_index) <= FTDI_RX;
                        rx_status <= waiting_end;
                        uart_rx_bit_index <= 7;
                    else 
                        uart_rx_reg(uart_rx_bit_index) <= FTDI_RX;
                        uart_rx_bit_index <= uart_rx_bit_index -1 ;
                    end if;


                when waiting_end =>
                    if (FTDI_RX = '1') then 
                        uart_rx_data_valid <= '1';
                    else 
                        -- corrupted data
                        report("Corrupted data!");
                    end if;
                    rx_status <= waiting_start;
            end case;
        end if;
    end process;

    BUFFER_MANAGER: process(uart_rx_data_valid)
    variable start_index : integer range 0 to 23;
    variable buffer_3byte : std_logic_vector(23 downto 0) := (others => '0');
    begin
        if rising_edge(uart_rx_data_valid) then
            report(integer'image(8*buffer_counter-1));
            start_index := 8*buffer_counter-1;
            buffer_3byte(start_index downto start_index - 7) := uart_rx_reg;
            buffer_counter <= buffer_counter - 1;

            if (buffer_counter = 1) then 
                buffer_counter <= 3;
                data_received <= buffer_3byte(23 downto 4);
                data_valid <= '1';
            end if;
        else
            data_valid <= '0';
        end if;
    end process;

end architecture Behaviour;
