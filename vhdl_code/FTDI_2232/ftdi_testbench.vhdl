library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ftdi_module_testbench is
end ftdi_module_testbench;

architecture testbench_arch of ftdi_module_testbench is

component FTDI_2232_RX
    Port(
        -- System ports
        master_clock : in std_logic;

        -- Receiving ports from USB module
        FTDI_RX : in std_logic;
        FTDI_CTS : in std_logic;

        -- Ports to core logic module
        data_received : out std_logic_vector(19 downto 0);
        data_valid : out std_logic := '0'
    );
end component;
    -- Constants
    constant CLK_PERIOD   : time := 83.33 ns;
    constant BAUD_PERIOD  : time := 1.667 us;
    
    -- UUT Signals
    signal master_clock   : std_logic := '0';
    signal FTDI_RX        : std_logic := '1';  -- Idle high
    signal FTDI_CTS       : std_logic := '0';
    signal data_received  : std_logic_vector(19 downto 0) := (others => '0');
    signal data_valid     : std_logic := '0';
    
    -- Testbench Signals
    signal tb_data        : std_logic_vector(19 downto 0) := (others => '0');
    signal tb_send        : std_logic := '0';
    signal expected_data : std_logic_vector(19 downto 0) := (others => '0');
    signal test_complete : boolean := false;
    signal debug_flag : std_logic := '0';
begin
    -- Instantiate UUT (your FTDI interface module)
    UUT: FTDI_2232_RX
    port map(
        master_clock => master_clock,
        FTDI_RX => FTDI_RX,
        FTDI_CTS => FTDI_CTS,
        data_received => data_received,
        data_valid => data_valid
    );
    
    -- Clock generation
    master_clock <= not master_clock after CLK_PERIOD/2 when not test_complete else '0';
    
    -- UART Transmitter Process (simulates FTDI output)
    stimuli: process
        procedure send_uart_byte(data : std_logic_vector(7 downto 0)) is
        begin
            -- Start bit
            FTDI_RX <= '0';
            wait for BAUD_PERIOD;
            
            -- Data bits (LSB first)
            for i in 7 downto 0 loop
                debug_flag <= '1';
                FTDI_RX <= data(i);
                wait for 1 ns;
                debug_flag <= '0';
                wait for BAUD_PERIOD - 1 ns;
            end loop;
            
            -- Stop bit
            FTDI_RX <= '1';
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
        report("Starting simulation");
        wait for 10 ns;
        
        -- Test case 1: Change variable 5 (header=0101) to xABCD
        report("Sending xABCD");
        send_20bit("0101" & x"ABCD");
        
        wait for 20 ns;
        
        -- Test case 2: Change variable 2 (header=0010) to x1234
        report("Sending x1234");
        send_20bit("0010" & x"1234");

        wait for 23 ns; 
        
        -- Test case 2: Change variable 2 (header=0010) to x1234
        report("Sending xAB34");
        send_20bit("0010" & x"AB34");

        wait for 1 ns;
        
        -- Test case 2: Change variable 2 (header=0010) to x1234
        report("Sending x1234");
        send_20bit("0010" & x"1234");

        wait for 10 ns;
        
        -- Test case 2: Change variable 2 (header=0010) to x1234
        report("Sending x12CD");
        send_20bit("0010" & x"12CD");
        wait for 500 ns;
        test_complete <= true;
        report("Simulation done!");
        wait;
    end process;
    
    -- Verification Process
    VERIFY: process(data_valid)
    begin
        if rising_edge(data_valid) then 
            assert data_received = expected_data
                report "Verification failed" 
                severity error;
        end if;
    end process;
    
end architecture testbench_arch;