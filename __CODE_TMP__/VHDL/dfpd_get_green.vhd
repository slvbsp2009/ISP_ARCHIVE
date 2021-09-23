library ieee, work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dfpd_get_green is
	generic
	(
		DATA_WIDTH_BITS			: natural-- := 10
	);
	port
	(
		clk			: in std_logic;
		reset		: in std_logic;

		g_p1		: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		g_m1		: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		c_0			: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		c_p2		: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		c_m2		: in unsigned(DATA_WIDTH_BITS-1 downto 0);

		green		: out unsigned(DATA_WIDTH_BITS-1 downto 0);

		run_en		: in std_logic
	);
end dfpd_get_green;


architecture IMPL of dfpd_get_green is

	signal g1		: unsigned(DATA_WIDTH_BITS-0 downto 0)		:= (others => '0');
	signal c1		: signed(DATA_WIDTH_BITS-0 downto 0)		:= (others => '0');
	signal c1_tmp	: unsigned(DATA_WIDTH_BITS-0 downto 0)		:= (others => '0');
	signal g2		: signed(DATA_WIDTH_BITS+2 downto 0)		:= (others => '0');

begin

	c1_tmp <= resize(c_p2, c1_tmp'length) + resize(c_m2, c1_tmp'length);

	process(clk)
	begin
		if rising_edge(clk) then
			if (run_en = '1') then
				-- step 1
				g1 <= resize(g_p1, g1'length) + resize(g_m1, g1'length);
				c1 <= signed('0'&c_0) - signed('0'&c1_tmp(c1_tmp'left downto 1));
				-- step 2
				g2 <= signed("00"&g1) + resize(c1, g2'length);
				-- step 3
				if (g2(g2'left) = '1') then
					green <= (others => '0');
				elsif (g2(g2'left-1) = '1') then
					green <= (others => '1');
				else
					green <= unsigned(g2(green'length downto 1));
				end if;
			end if;
		end if;
	end process;

end architecture IMPL;
