library IEEE;
use IEEE.std_logic_1164.all;

package utils is 
    function to_hstring(slv : std_logic_vector) return string;
end package utils;

package body utils is 

    function to_hstring(slv : std_logic_vector) return string is
        variable hexlen : integer;
        variable longslv : std_logic_vector(67 downto 0) := (others => '0');
        variable hex : string(1 to 16);
        variable fourbit : std_logic_vector(3 downto 0);
    begin
        hexlen := (slv'length + 3)/4;
        longslv(slv'length-1 downto 0) := slv;
        
        for i in 0 to hexlen-1 loop
            fourbit := longslv(((i*4)+3) downto (i*4));
            case fourbit is
                when "0000" => hex(hexlen-i) := '0';
                when "0001" => hex(hexlen-i) := '1';
                when "0010" => hex(hexlen-i) := '2';
                when "0011" => hex(hexlen-i) := '3';
                when "0100" => hex(hexlen-i) := '4';
                when "0101" => hex(hexlen-i) := '5';
                when "0110" => hex(hexlen-i) := '6';
                when "0111" => hex(hexlen-i) := '7';
                when "1000" => hex(hexlen-i) := '8';
                when "1001" => hex(hexlen-i) := '9';
                when "1010" => hex(hexlen-i) := 'A';
                when "1011" => hex(hexlen-i) := 'B';
                when "1100" => hex(hexlen-i) := 'C';
                when "1101" => hex(hexlen-i) := 'D';
                when "1110" => hex(hexlen-i) := 'E';
                when "1111" => hex(hexlen-i) := 'F';
                when others => hex(hexlen-i) := 'X';
            end case;
        end loop;
        
        return hex(1 to hexlen);
    end function;

end package body utils;