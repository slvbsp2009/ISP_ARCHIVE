library ieee, work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dfpd_get_greens_hv is
	generic
	(
		DATA_WIDTH_BITS		: natural;-- := 10;
		IMAGE_WIDTH_BITS	: natural;-- := 12;
		IMAGE_HEIGHT_BITS	: natural;-- := 11;
		MAX_IMAGE_WIDTH		: natural;
		KERNEL_H			: natural;-- := 9;
		KERNEL_W			: natural-- := 9
	);
	port
	(
		clk			: in std_logic;
		reset		: in std_logic;

		sdata			: in std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		sdata_valid		: in std_logic;
		sdata_ready		: out std_logic;

		mdata_gh		: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_gv		: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_raw		: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_valid		: out std_logic;
		mdata_ready		: in std_logic;

		n_cols_in		: in unsigned(IMAGE_WIDTH_BITS-1 downto 0);
		n_rows_in		: in unsigned(IMAGE_HEIGHT_BITS-1 downto 0)
	);
end dfpd_get_greens_hv;


architecture IMPL of dfpd_get_greens_hv is

	constant TOTAL_DELAY	: natural 	:= 3;

	signal ker_data				: std_logic_vector(KERNEL_H*KERNEL_W*DATA_WIDTH_BITS-1 downto 0);
	signal ker_data_valid		: std_logic;
	signal ker_data_ready		: std_logic;

	impure function data(r,c:integer; bus_data:std_logic_vector) return unsigned is
		constant offset	: integer	:= ((c+KERNEL_W/2)*KERNEL_H + (r+KERNEL_H/2)) * DATA_WIDTH_BITS;
	begin
		return unsigned(bus_data(offset+DATA_WIDTH_BITS-1 downto offset));
	end;

    signal valids		: std_logic_vector(TOTAL_DELAY-1 downto 0)		:= (others => '0');
	signal valid_o		: std_logic;
	signal run_en		: std_logic;

	signal gh33_g_p1		: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal gh33_g_m1		: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal gh33_c_0			: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal gh33_c_p2		: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal gh33_c_m2		: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal gv33_g_p1		: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal gv33_g_m1		: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal gv33_c_0			: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal gv33_c_p2		: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal gv33_c_m2		: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal gh33				: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal gv33				: unsigned(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal arr_raw			: std_logic_vector(TOTAL_DELAY*DATA_WIDTH_BITS-1 downto 0) := (others => '0');

	-- type test_t is array (0 to 4, 0 to 4) of std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	-- signal test		: test_t;

begin
		kernel_top_inst : entity work.kernel_top
			generic map
			(
				DATA_WIDTH_BITS		=> DATA_WIDTH_BITS,
				IMAGE_WIDTH_BITS	=> IMAGE_WIDTH_BITS,
				IMAGE_HEIGHT_BITS	=> IMAGE_HEIGHT_BITS,
				MAX_IMAGE_WIDTH		=> MAX_IMAGE_WIDTH,
				KERNEL_H			=> KERNEL_H,
				KERNEL_W			=> KERNEL_W
			)
			port map
			(
				clk				=> clk,
				reset			=> reset,

				sdata			=> sdata,
				sdata_valid		=> sdata_valid,
				sdata_ready		=> sdata_ready,

				mdata			=> ker_data,
				mdata_valid		=> ker_data_valid,
				mdata_ready		=> ker_data_ready,

				n_cols_in		=> n_cols_in,
				n_rows_in		=> n_rows_in,
				n_cols_out		=> open,
				n_rows_out		=> open

			);

		mdata_gv		<= std_logic_vector(gv33);
		mdata_gh		<= std_logic_vector(gh33);
		mdata_raw		<= arr_raw(arr_raw'left downto arr_raw'left-DATA_WIDTH_BITS+1);
	    mdata_valid		<= valid_o;
	    ker_data_ready	<= run_en;
	    valid_o			<= valids(valids'left);
		run_en			<= mdata_ready or not(valid_o);

-- gr:
--     for r in  0 to 4 generate
--     gc:
--         for c in 0 to 4 generate
-- 			process(ker_data)
-- 			begin
-- 				test(r,c) <= std_logic_vector(data(r-2,c-2));
-- 			end process;
--     end generate;
-- end generate;

		gh33_g_p1		<= data(0,1, ker_data);
		gh33_g_m1		<= data(0,-1, ker_data);
		gh33_c_0		<= data(0,0, ker_data);
		gh33_c_p2		<= data(0,2, ker_data);
		gh33_c_m2		<= data(0,-2, ker_data);

		gh33_inst: entity work.dfpd_get_green
			generic map (DATA_WIDTH_BITS)
			port map
			(
				clk			=> clk,
				reset		=> reset,
				g_p1		=> gh33_g_p1,
				g_m1		=> gh33_g_m1,
				c_0			=> gh33_c_0,
				c_p2		=> gh33_c_p2,
				c_m2		=> gh33_c_m2,
				green		=> gh33,
				run_en		=> run_en
			);

		gv33_g_p1		<= data( 1,0, ker_data);
		gv33_g_m1		<= data(-1,0, ker_data);
		gv33_c_0		<= data( 0,0, ker_data);
		gv33_c_p2		<= data( 2,0, ker_data);
		gv33_c_m2		<= data(-2,0, ker_data);

		gv33_inst: entity work.dfpd_get_green
			generic map (DATA_WIDTH_BITS)
			port map
			(
				clk			=> clk,
				reset		=> reset,
				g_p1		=> gv33_g_p1,
				g_m1		=> gv33_g_m1,
				c_0			=> gv33_c_0,
				c_p2		=> gv33_c_p2,
				c_m2		=> gv33_c_m2,
				green		=> gv33,
				run_en		=> run_en
			);

		process(clk)
		begin
			if rising_edge(clk) then
				if (reset = '1') then
					valids	<= (others =>'0');
				else
					if (run_en = '1') then
						valids <= valids(valids'left-1 downto 0) & ker_data_valid;
					end if;
				end if;

				if (run_en = '1') then
					arr_raw <= arr_raw((TOTAL_DELAY-1)*DATA_WIDTH_BITS-1 downto 0) & std_logic_vector(data(0,0,ker_data));
				end if;
			end if;
		end process;

end architecture IMPL;
