-- =================================================
-- restoring green pixel in position 33
--			d11 d12 d13 d14 d15
--			d21 d22 d23 d24 d25
--			d31 d32 d33 d34 d35
--			d41 d42 d43 d44 d45
--			d51 d52 d53 d54 d55
-- 		h = (abs(A22-A24) + abs(A44-A42) + abs(A32-A34) + abs(A33-A31) + abs(A33-A35))/5;
-- 		v = (abs(A22-A42) + abs(A24-A44) + abs(A23-A43) + abs(A33-A13) + abs(A33-A53))/5;
-- 			if (h < v)
-- 				G33 = (A32+A34)/2 + (A33 - A31/2 - A35/2)/2;
-- 			else
-- 				G33 = (A23+A43)/2 + (A33 - A13/2 - A53/2)/2;
-- 			end;
-- =================================================


library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pipe_pkg.all;

entity debayering_green is
	generic
	(
		DATA_WIDTH_BITS		: natural := 10;

		PIPE_DELAY			: natural := 3
	);
	port
	(
		clk				: in std_logic;
		reset			: in std_logic;

		run_en			: in std_logic;

		s13				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s22				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s23				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s24				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s31				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s32				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s33				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s34				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s35				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s42				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s43				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s44				: in unsigned(DATA_WIDTH_BITS-1 downto 0);
		s53				: in unsigned(DATA_WIDTH_BITS-1 downto 0);

		G_out			: out unsigned(DATA_WIDTH_BITS-1 downto 0)

	);
end debayering_green;

architecture a1 of debayering_green is

	signal a22m24 			: unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal a44m42 			: unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal a32m34 			: unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal a33m31 			: unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal a33m35 			: unsigned(DATA_WIDTH_BITS-1 downto 0);

	signal a22m42 			: unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal a44m24 			: unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal a23m43 			: unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal a33m13 			: unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal a33m53 			: unsigned(DATA_WIDTH_BITS-1 downto 0);

	signal sumh_1 			: unsigned(DATA_WIDTH_BITS+0 downto 0);
	signal sumh_2 			: unsigned(DATA_WIDTH_BITS+0 downto 0);
	signal sumv_1 			: unsigned(DATA_WIDTH_BITS+0 downto 0);
	signal sumv_2 			: unsigned(DATA_WIDTH_BITS+0 downto 0);

	signal Gh_1, Gv_1		: unsigned(DATA_WIDTH_BITS-0 downto 0);
	signal Gh, Gv			: signed(DATA_WIDTH_BITS+2 downto 0);
	signal Gh_2, Gv_2		: signed(DATA_WIDTH_BITS-0 downto 0);

	function abs_udiff(A, B: unsigned) return unsigned is
		variable d_abs		: unsigned(A'range);
	begin
		if (A>B) then	d_abs := A-B;
		else			d_abs := B-A;
		end if;
		return d_abs;
	end;

begin

	process(clk)
		variable sumh_2_var 		: unsigned(DATA_WIDTH_BITS-0 downto 0);
		variable sumv_2_var 		: unsigned(DATA_WIDTH_BITS-0 downto 0);
		variable h 					: unsigned(DATA_WIDTH_BITS-1 downto 0);
		variable v	 				: unsigned(DATA_WIDTH_BITS-1 downto 0);
		variable sum3135			: unsigned(DATA_WIDTH_BITS-0 downto 0);
		variable sum1353			: unsigned(DATA_WIDTH_BITS-0 downto 0);
		variable Gh_var, Gv_var		: unsigned(DATA_WIDTH_BITS-1 downto 0);
	begin
		if clk'event and clk = '1' then
			if (reset = '1') then
				a22m24 <= (others => '0');
				a44m42 <= (others => '0');
				a32m34 <= (others => '0');
				a33m31 <= (others => '0');
				a33m35 <= (others => '0');
				a22m42 <= (others => '0');
				a44m24 <= (others => '0');
				a23m43 <= (others => '0');
				a33m13 <= (others => '0');
				a33m53 <= (others => '0');

				Gh_1 <= (others => '0');
				Gh_2 <= (others => '0');
				Gv_1 <= (others => '0');
				Gv_2 <= (others => '0');

				sumh_1 <= (others => '0');
				sumh_2 <= (others => '0');
				sumv_1 <= (others => '0');
				sumv_2 <= (others => '0');

				Gh <= (others => '0');
				Gv <= (others => '0');
				h := (others => '0');
				v := (others => '0');

				Gh_var := (others => '0');
				Gv_var := (others => '0');
				sumh_2_var	:= (others => '0');
				sumv_2_var	:= (others => '0');
				sum3135		:= (others => '0');
				sum1353		:= (others => '0');

			else
				sumh_2_var := shift_right(resize(a32m34, DATA_WIDTH_BITS+1) + resize(a33m31, DATA_WIDTH_BITS+1), 1);
				sumv_2_var := shift_right(resize(a23m43, DATA_WIDTH_BITS+1) + resize(a33m13, DATA_WIDTH_BITS+1), 1);

				sum3135 := shift_right(resize(s31, DATA_WIDTH_BITS+1) + resize(s35, DATA_WIDTH_BITS+1), 1);
				sum1353 := shift_right(resize(s13, DATA_WIDTH_BITS+1) + resize(s53, DATA_WIDTH_BITS+1), 1);

				if (run_en = '1') then
					-- step 1
					a22m24 <= abs_udiff(s22, s24);
					a44m42 <= abs_udiff(s44, s42);
					a32m34 <= abs_udiff(s32, s34);
					a33m31 <= abs_udiff(s33, s31);
					a33m35 <= abs_udiff(s33, s35);

					a22m42 <= abs_udiff(s22, s42);
					a44m24 <= abs_udiff(s44, s24);
					a23m43 <= abs_udiff(s23, s43);
					a33m13 <= abs_udiff(s33, s13);
					a33m53 <= abs_udiff(s33, s53);

					Gh_1 <= resize(s32, DATA_WIDTH_BITS+1) + resize(s34, DATA_WIDTH_BITS+1);
					Gh_2 <= signed(resize(s33, DATA_WIDTH_BITS+1)) - signed(resize(sum3135, DATA_WIDTH_BITS+1));
					-- Gh_2 <= (others => '0');

					Gv_1 <= resize(s23, DATA_WIDTH_BITS+1) + resize(s43, DATA_WIDTH_BITS+1);
					Gv_2 <= signed(resize(s33, DATA_WIDTH_BITS+1)) - signed(resize(sum1353, DATA_WIDTH_BITS+1));
					-- Gv_2 <= (others => '0');

					-- step 2
					sumh_1 <= shift_right(resize(a22m24, DATA_WIDTH_BITS+1) + resize(a44m42, DATA_WIDTH_BITS+1), 1);
					sumh_2 <= shift_right(sumh_2_var + resize(a33m35, DATA_WIDTH_BITS+1), 1);

					sumv_1 <= shift_right(resize(a22m42, DATA_WIDTH_BITS+1) + resize(a44m24, DATA_WIDTH_BITS+1), 1);
					sumv_2 <= shift_right(sumv_2_var + resize(a33m53, DATA_WIDTH_BITS+1), 1);

					-- Gh <= shift_right((signed(resize(Gh_1, DATA_WIDTH_BITS+3)) + signed(resize(Gh_2, DATA_WIDTH_BITS+3))), 1);
					-- Gv <= shift_right((signed(resize(Gv_1, DATA_WIDTH_BITS+3)) + signed(resize(Gv_2, DATA_WIDTH_BITS+3))), 1);
					Gh <= shift_right((signed(resize(Gh_1, DATA_WIDTH_BITS+3)) + signed(resize(shift_right(Gh_2,1), DATA_WIDTH_BITS+3))), 1);
					Gv <= shift_right((signed(resize(Gv_1, DATA_WIDTH_BITS+3)) + signed(resize(shift_right(Gv_2,1), DATA_WIDTH_BITS+3))), 1);


					-- step 3
					h := resize(shift_right(sumh_1 + sumh_2, 1), DATA_WIDTH_BITS);
					v := resize(shift_right(sumv_1 + sumv_2, 1), DATA_WIDTH_BITS);

					if (Gh(Gh'length-1) = '1') then
						Gh_var := (others => '0');
					elsif (Gh(DATA_WIDTH_BITS) = '1') or (Gh(DATA_WIDTH_BITS+1) = '1') then
						Gh_var := (others => '1');
					else
						Gh_var := resize(unsigned(Gh), DATA_WIDTH_BITS);
					end if;

					if (Gv(Gv'length-1) = '1') then
						Gv_var := (others => '0');
					elsif (Gv(DATA_WIDTH_BITS) = '1') or (Gv(DATA_WIDTH_BITS+1) = '1') then
						Gv_var := (others => '1');
					else
						Gv_var := resize(unsigned(Gv), DATA_WIDTH_BITS);
					end if;

					if (h < v) then
						G_out <= Gh_var;
					else
						G_out <= Gv_var;
					end if;
				end if;
			end if;
		end if;
	end process;
end a1;
