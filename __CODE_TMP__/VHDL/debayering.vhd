library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pipe_pkg.all;

entity debayering is
	generic
	(
		DATA_WIDTH_BITS		: natural := 10;
		IMAGE_WIDTH_BITS	: natural;-- := 12;
		IMAGE_HEIGHT_BITS	: natural;-- := 11;
		KERNEL_H			: natural := 7;
		KERNEL_W			: natural := 7;

		PIPE_DELAY			: natural := 6
	);
	port
	(
		clk				: in std_logic;
		reset			: in std_logic;

		sdata			: in std_logic_vector(KERNEL_H*KERNEL_W*DATA_WIDTH_BITS-1 downto 0);
		sdata_valid		: in std_logic;
		sdata_ready		: out std_logic;

		mdata_r			: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_g			: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_b			: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_valid		: out std_logic;
		mdata_ready		: in std_logic;

		n_cols_in		: in unsigned(IMAGE_WIDTH_BITS-1 downto 0);
		n_rows_in		: in unsigned(IMAGE_HEIGHT_BITS-1 downto 0);
		n_cols_out		: out unsigned(IMAGE_WIDTH_BITS-1 downto 0);
		n_rows_out		: out unsigned(IMAGE_HEIGHT_BITS-1 downto 0);

		db_en			: in std_logic;
		shift_R			: in std_logic;
		shift_C			: in std_logic
	);
end debayering;

architecture a1 of debayering is

	signal run_en						: std_logic;
	signal mdata_valid_o				: std_logic;
	signal data_valid_cnt				: unsigned(log2(PIPE_DELAY)-1 downto 0);

	type kernel_type is array (0 to KERNEL_H*KERNEL_W-1) of unsigned (DATA_WIDTH_BITS-1 downto 0);
	signal k	: kernel_type;

	signal col		: unsigned(IMAGE_WIDTH_BITS-1 downto 0);
	signal row		: unsigned(IMAGE_HEIGHT_BITS-1 downto 0);

	signal	d11, d12, d13, d14, d15, d16, d17:		unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal	d21, d22, d23, d24, d25, d26, d27:		unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal	d31, d32, d33, d34, d35, d36, d37:		unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal	d41, d42, d43, d44, d45, d46, d47:		unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal	d51, d52, d53, d54, d55, d56, d57:		unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal	d61, d62, d63, d64, d65, d66, d67:		unsigned(DATA_WIDTH_BITS-1 downto 0);
	signal	d71, d72, d73, d74, d75, d76, d77:		unsigned(DATA_WIDTH_BITS-1 downto 0);

	signal color		: std_logic_vector(1 downto 0);
	signal color_c1		: std_logic_vector(1 downto 0);
	signal color_c2		: std_logic_vector(1 downto 0);
	signal color_c3		: std_logic_vector(1 downto 0);
	signal color_c4		: std_logic_vector(1 downto 0);
	signal color_c5		: std_logic_vector(1 downto 0);
	signal rr, cc		: std_logic;

	signal G33, G34, G35	: unsigned(DATA_WIDTH_BITS-1 downto 0)		:= (others => '0');
	signal G43, G44, G45	: unsigned(DATA_WIDTH_BITS-1 downto 0)		:= (others => '0');
	signal G53, G54, G55	: unsigned(DATA_WIDTH_BITS-1 downto 0)		:= (others => '0');

	-- signal G33_c1, G34_c1, G35_c1	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	-- signal G43_c1, G44_c1, G45_c1	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	-- signal G53_c1, G54_c1, G55_c1	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal G44_c1	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal G44_c2	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');

	signal d33_c1, d34_c1, d35_c1	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal d43_c1, d44_c1, d45_c1	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal d53_c1, d54_c1, d55_c1	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');

	signal d33_c2, d34_c2, d35_c2	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal d43_c2, d44_c2, d45_c2	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal d53_c2, d54_c2, d55_c2	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');

	signal d33_c3, d34_c3, d35_c3	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal d43_c3, d44_c3, d45_c3	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal d53_c3, d54_c3, d55_c3	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal d44_c4, d44_c5			: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');


	signal Ch34 				: signed(DATA_WIDTH_BITS-0 downto 0)	:= (others => '0');
	signal Ch43, Ch45			: signed(DATA_WIDTH_BITS-0 downto 0)	:= (others => '0');
	signal Ch54 				: signed(DATA_WIDTH_BITS-0 downto 0)	:= (others => '0');
	signal Ch33p35, Ch53p55		: signed(DATA_WIDTH_BITS+1 downto 0)	:= (others => '0');
	signal C_h, C_v, C_c		: signed(DATA_WIDTH_BITS+1 downto 0)	:= (others => '0');

	signal R			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0)		:= (others => '0');
	signal G			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0)		:= (others => '0');
	signal B			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0)		:= (others => '0');

begin

    sdata_ready     <= mdata_ready;-- and not(reset);
    mdata_valid		<= sdata_valid and mdata_valid_o;
	run_en			<= mData_ready and sdata_valid;

	mdata_r			<= R;
	mdata_g			<= G;
	mdata_b			<= B;

	data_in_inst: for i in 0 to KERNEL_H*KERNEL_W-1 generate
		k(i) <= unsigned(sdata((i+1)*DATA_WIDTH_BITS-1 downto i*DATA_WIDTH_BITS));
	end generate data_in_inst;

	d11 <= k(0); d12 <=k(7);  d13 <=k(14); d14 <=k(21); d15 <=k(28); d16 <=k(35); d17 <=k(42);
	d21 <= k(1); d22 <=k(8);  d23 <=k(15); d24 <=k(22); d25 <=k(29); d26 <=k(36); d27 <=k(43);
	d31 <= k(2); d32 <=k(9);  d33 <=k(16); d34 <=k(23); d35 <=k(30); d36 <=k(37); d37 <=k(44);
	d41 <= k(3); d42 <=k(10); d43 <=k(17); d44 <=k(24); d45 <=k(31); d46 <=k(38); d47 <=k(45);
	d51 <= k(4); d52 <=k(11); d53 <=k(18); d54 <=k(25); d55 <=k(32); d56 <=k(39); d57 <=k(46);
	d61 <= k(5); d62 <=k(12); d63 <=k(19); d64 <=k(26); d65 <=k(33); d66 <=k(40); d67 <=k(47);
	d71 <= k(6); d72 <=k(13); d73 <=k(20); d74 <=k(27); d75 <=k(34); d76 <=k(41); d77 <=k(48);

	rr		<= row(0) xor shift_R;
	cc		<= col(0) xor shift_C;
	color	<= rr&cc;

	process(clk)
	begin
		if clk'event and clk = '1' then
			if (reset = '1') then
				col		<= (others => '0');
				row		<= (others => '0');
			else
				if (run_en = '1') and (sdata_valid = '1') then
				-- if (run_en = '1') then
					if (col = n_cols_in-1) then
						col <= (others => '0');
						if (row = n_rows_in-1) then
							row <= (others => '0');
						else
							row <= row + 1;
						end if;
					else
						col <= col + 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- steps 1-3;
	process(clk)
	begin
		if clk'event and clk = '1' then
			if (reset = '1') then
				G34	<= (others => '0');
				G44	<= (others => '0');
				G54	<= (others => '0');
				G35	<= (others => '0');
				G45	<= (others => '0');
				G55	<= (others => '0');
				color_c1	<= (others => '0');
				color_c2	<= (others => '0');
				color_c3	<= (others => '0');
			else
				if (run_en = '1') then
					color_c1 <= color;
					color_c2 <= color_c1;
					color_c3 <= color_c2;
					G34	<= G33;	G35	<= G34;
					G44	<= G43;	G45	<= G44;
					G54	<= G53;	G55	<= G54;

					d33_c1 <= d33;    d34_c1 <= d34;    d35_c1 <= d35;
					d43_c1 <= d43;    d44_c1 <= d44;    d45_c1 <= d45;
					d53_c1 <= d53;    d54_c1 <= d54;    d55_c1 <= d55;
					d33_c2 <= d33_c1; d34_c2 <= d34_c1; d35_c2 <= d35_c1;
					d43_c2 <= d43_c1; d44_c2 <= d44_c1; d45_c2 <= d45_c1;
					d53_c2 <= d53_c1; d54_c2 <= d54_c1; d55_c2 <= d55_c1;
					d33_c3 <= d33_c2; d34_c3 <= d34_c2; d35_c3 <= d35_c2;
					d43_c3 <= d43_c2; d44_c3 <= d44_c2; d45_c3 <= d45_c2;
					d53_c3 <= d53_c2; d54_c3 <= d54_c2; d55_c3 <= d55_c2;

				end if;
			end if;
		end if;
	end process;

	-- steps 4;
	process(clk)
		variable Ch33_var, Ch35_var	: signed(DATA_WIDTH_BITS-0 downto 0)	:= (others => '0');
		variable Ch53_var, Ch55_var	: signed(DATA_WIDTH_BITS-0 downto 0)	:= (others => '0');
		variable C_c_var			: signed(DATA_WIDTH_BITS+2 downto 0)	:= (others => '0');
		variable RR, GG, BB			: signed(DATA_WIDTH_BITS+1 downto 0)	:= (others => '0');

	begin
		if clk'event and clk = '1' then
			if (reset = '1') then
				color_c4	<= (others => '0');
				color_c5	<= (others => '0');
			else
				Ch33_var := signed(resize(d33_c3, DATA_WIDTH_BITS+1)) - signed(resize(G33, DATA_WIDTH_BITS+1));
				Ch35_var := signed(resize(d35_c3, DATA_WIDTH_BITS+1)) - signed(resize(G35, DATA_WIDTH_BITS+1));

				Ch53_var := signed(resize(d53_c3, DATA_WIDTH_BITS+1)) - signed(resize(G53, DATA_WIDTH_BITS+1));
				Ch55_var := signed(resize(d55_c3, DATA_WIDTH_BITS+1)) - signed(resize(G55, DATA_WIDTH_BITS+1));

				-- steps 4;
				if (run_en = '1') then
					color_c4 <= color_c3;
					Ch33p35 <= resize(Ch33_var, DATA_WIDTH_BITS+2) + resize(Ch35_var, DATA_WIDTH_BITS+2);
					Ch53p55 <= resize(Ch53_var, DATA_WIDTH_BITS+2) + resize(Ch55_var, DATA_WIDTH_BITS+2);

					Ch34 <= signed(resize(d34_c3, DATA_WIDTH_BITS+1)) - signed(resize(G34, DATA_WIDTH_BITS+1));
					Ch43 <= signed(resize(d43_c3, DATA_WIDTH_BITS+1)) - signed(resize(G43, DATA_WIDTH_BITS+1));
					Ch45 <= signed(resize(d45_c3, DATA_WIDTH_BITS+1)) - signed(resize(G45, DATA_WIDTH_BITS+1));
					Ch54 <= signed(resize(d54_c3, DATA_WIDTH_BITS+1)) - signed(resize(G54, DATA_WIDTH_BITS+1));

					-- G33_c1 <= G33; G34_c1 <= G34; G35_c1 <= G35;
					-- G43_c1 <= G43; G44_c1 <= G44; G45_c1 <= G45;
					-- G53_c1 <= G53; G54_c1 <= G54; G55_c1 <= G55;
					G44_c1 <= G44;
					d44_c4 <= d44_c3;
				end if;

				C_c_var := shift_right(resize(Ch33p35, DATA_WIDTH_BITS+3) + resize(Ch53p55, DATA_WIDTH_BITS+3), 1);

				-- steps 5;
				if (run_en = '1') then
					color_c5 <= color_c4;
					G44_c2 <= G44_c1;
					d44_c5 <= d44_c4;

					C_h <= signed(resize(d44_c4, DATA_WIDTH_BITS+2)) + shift_right(resize(Ch43, DATA_WIDTH_BITS+2) + resize(Ch45, DATA_WIDTH_BITS+2), 1);
					C_v <= signed(resize(d44_c4, DATA_WIDTH_BITS+2)) + shift_right(resize(Ch34, DATA_WIDTH_BITS+2) + resize(Ch54, DATA_WIDTH_BITS+2), 1);
					C_c <= signed(resize(G44_c1, DATA_WIDTH_BITS+2)) + shift_right(resize(C_c_var, DATA_WIDTH_BITS+2), 1);
				end if;

				case color_c5 is
					when "00" =>	--greenR
						RR := C_h;
						GG := signed(resize(d44_c5, DATA_WIDTH_BITS+2));
						BB := C_v;
					when "01" =>	--red
						RR := signed(resize(d44_c5, DATA_WIDTH_BITS+2));
						GG := signed(resize(G44_c2, DATA_WIDTH_BITS+2));
						BB := C_c;
					when "10" =>	--blue
						BB := signed(resize(d44_c5, DATA_WIDTH_BITS+2));
						GG := signed(resize(G44_c2, DATA_WIDTH_BITS+2));
						RR := C_c;
					when others =>	--greenB
						RR := C_v;
						GG := signed(resize(d44_c5, DATA_WIDTH_BITS+2));
						BB := C_h;
				end case;

				-- steps 6;
				if (run_en = '1') then
					if (db_en = '1') then
						if RR(DATA_WIDTH_BITS+1) = '1' then
							R <= (others => '0');
						elsif RR(DATA_WIDTH_BITS) = '1' then
							R <= (others => '1');
						else
							R <= std_logic_vector(RR(DATA_WIDTH_BITS-1 downto 0));
						end if;

						if GG(DATA_WIDTH_BITS+1) = '1' then
							G <= (others => '0');
						elsif GG(DATA_WIDTH_BITS) = '1' then
							G <= (others => '1');
						else
							G <= std_logic_vector(GG(DATA_WIDTH_BITS-1 downto 0));
						end if;

						if BB(DATA_WIDTH_BITS+1) = '1' then
							B <= (others => '0');
						elsif BB(DATA_WIDTH_BITS) = '1' then
							B <= (others => '1');
						else
							B <= std_logic_vector(BB(DATA_WIDTH_BITS-1 downto 0));
						end if;

-- R <= d44_c5;
-- G <= d44_c5;
-- B <= d44_c5;
					else
						R <= std_logic_vector(d44_c5);
						G <= std_logic_vector(d44_c5);
						B <= std_logic_vector(d44_c5);
					end if;
				end if;
			end if;
		end if;
	end process;


	G33_inst : entity work.debayering_green
		generic map
		(
			DATA_WIDTH_BITS	=> DATA_WIDTH_BITS
		)
		port map
		(
			clk				=> clk,
			reset			=> reset,

			run_en			=> run_en,

			s13				=> d13,
			s22				=> d22,
			s23				=> d23,
			s24				=> d24,
			s31				=> d31,
			s32				=> d32,
			s33				=> d33,
			s34				=> d34,
			s35				=> d35,
			s42				=> d42,
			s43				=> d43,
			s44				=> d44,
			s53				=> d53,

			G_out			=> G33
		);

	G43_inst : entity work.debayering_green
		generic map
		(
			DATA_WIDTH_BITS	=> DATA_WIDTH_BITS
		)
		port map
		(
			clk				=> clk,
			reset			=> reset,

			run_en			=> run_en,

			s13				=> d23,
			s22				=> d32,
			s23				=> d33,
			s24				=> d34,
			s31				=> d41,
			s32				=> d42,
			s33				=> d43,
			s34				=> d44,
			s35				=> d45,
			s42				=> d52,
			s43				=> d53,
			s44				=> d54,
			s53				=> d63,

			G_out			=> G43
		);

	G53_inst : entity work.debayering_green
		generic map
		(
			DATA_WIDTH_BITS	=> DATA_WIDTH_BITS
		)
		port map
		(
			clk				=> clk,
			reset			=> reset,

			run_en			=> run_en,

			s13				=> d33,
			s22				=> d42,
			s23				=> d43,
			s24				=> d44,
			s31				=> d51,
			s32				=> d52,
			s33				=> d53,
			s34				=> d54,
			s35				=> d55,
			s42				=> d62,
			s43				=> d63,
			s44				=> d64,
			s53				=> d73,

			G_out			=> G53
		);

	process(clk)
	begin
		if rising_edge(clk) then
			n_cols_out <= n_cols_in;
			n_rows_out <= n_rows_in;
		end if;
	end process;

	process(clk)
	begin
		if clk'event and clk = '1' then
			if (reset = '1') then
				mdata_valid_o	<= '0';
				data_valid_cnt	<= (others => '0');
			else
				if (run_en = '1') then
					if (data_valid_cnt = PIPE_DELAY-1) then
						mdata_valid_o <= '1';
					else
						data_valid_cnt <= data_valid_cnt + 1;
						mdata_valid_o <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;

end a1;
