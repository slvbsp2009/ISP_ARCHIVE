
library ieee, work, std;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

--------------------------------------
--	delay_vector_en	--
--------------------------------------
entity delay_vector_en is
	generic
	(
		delay	: integer := 1;
		msb		: integer := 3
	);
	port
	(
		clk   : in     std_logic;
		d_in  : in     std_logic_vector(msb downto 0);
		d_out : out    std_logic_vector(msb downto 0);
		en    : in     std_logic;
		reset : in     std_logic
	);
end entity delay_vector_en;

architecture a0 of delay_vector_en is

begin

	process(clk,reset)
		type delay_line is array(delay downto 0) of std_logic_vector(msb downto 0);
		variable shift_reg:delay_line;
	begin
		if clk'event and clk = '1' then
			if reset = '1' then
				shift_reg := (others => (others => '0'));
				d_out  <= (others => '0');
			else
				if en = '1' then
					shift_reg(0) := d_in;
					shift_reg(delay downto 1) := shift_reg((delay-1) downto 0);
					d_out <= shift_reg(delay);
				end if;
			end if;
		end if;
	end process;

end architecture a0 ; -- of delay_vector_en

--------------------------------------
--	uuMULT	--
-- real delay is PIPE+1
--------------------------------------
library ieee, work, std;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity uuMULT is
	generic
	(
		A_BITS 	: integer := 8;
		B_BITS 	: integer := 8;
		PIPE	: integer := 4
	);
	port
	(
		clk:	in std_logic;
		a:		in std_logic_VECTOR(A_BITS-1 downto 0);
		b:		in std_logic_VECTOR(B_BITS-1 downto 0);
		ce:		in std_logic;
		c: 		out std_logic_VECTOR(A_BITS+B_BITS-1 downto 0)
	);
end uuMULT;

architecture Behavioral of uuMULT is
	type	mult_result_array is array (0 to PIPE) of std_logic_vector(A_BITS+B_BITS-1 downto 0);
	signal	pipeline_array 	: mult_result_array;

	attribute USE_DSP48 : string;
	attribute USE_DSP48 of pipeline_array : signal is "YES";

begin
	process (clk)
	begin
		if (clk'event and clk = '1') then
			if (ce = '1') then
				pipeline_array(0) <= a * b;
				for i in 1 to PIPE loop
					pipeline_array(i) <= pipeline_array(i-1);
				end loop;
			end if;
		end if;
	end process;
	c <= pipeline_array(PIPE);
end Behavioral;
