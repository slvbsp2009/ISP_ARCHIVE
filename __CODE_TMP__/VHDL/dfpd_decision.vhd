library ieee, work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dfpd_decision is
	generic
	(
		DATA_WIDTH_BITS		: natural;-- := 10;
		IMAGE_WIDTH_BITS	: natural;-- := 12;
		IMAGE_HEIGHT_BITS	: natural;-- := 11;
		MAX_IMAGE_WIDTH		: natural
	);
	port
	(
		clk			: in std_logic;
		reset		: in std_logic;

		sdata_gh		: in std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		sdata_gv		: in std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		sdata_raw		: in std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		sdata_valid		: in std_logic;
		sdata_ready		: out std_logic;

		mdata_dir		: out std_logic;	-- 0- hor; 1- vert
		mdata_g			: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_g_orig	: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_rb_orig	: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_valid		: out std_logic;
		mdata_ready		: in std_logic;

		n_cols_in		: in unsigned(IMAGE_WIDTH_BITS-1 downto 0);
		n_rows_in		: in unsigned(IMAGE_HEIGHT_BITS-1 downto 0);
		g_init			: in std_logic;
		rb_init			: in std_logic

	);
end dfpd_decision;


architecture IMPL of dfpd_decision is

	constant KERNEL_H		: natural	:= 5;
	constant KERNEL_W		: natural	:= 3;

	constant TOTAL_DELAY	: natural 	:= 6;

	signal n_cols_div2			: unsigned(IMAGE_WIDTH_BITS-2 downto 0);
	signal ker_sdata			: std_logic_vector(3*DATA_WIDTH_BITS-1 downto 0);
	signal ker_sdata_valid		: std_logic;
	signal ker_sdata_ready		: std_logic;
	signal ker_mdata			: std_logic_vector(KERNEL_H*KERNEL_W*3*DATA_WIDTH_BITS-1 downto 0);
	signal ker_mdata_valid		: std_logic;
	signal ker_mdata_ready		: std_logic;

	signal sync_sdata			: std_logic_vector(2*DATA_WIDTH_BITS+1-1 downto 0);
	signal sync_sdata_valid		: std_logic;
	signal sync_sdata_ready		: std_logic;

	signal fifo_sdata			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal fifo_sdata_valid		: std_logic;
	signal fifo_sdata_ready		: std_logic;

	signal sync_m1data			: std_logic_vector(2*DATA_WIDTH_BITS+1-1 downto 0);
	signal sync_m2data			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal sync_mdata_valid		: std_logic;
	signal sync_mdata_ready		: std_logic;

	impure
	function data(r,c,i:integer; bus_data:std_logic_vector) return unsigned is
		constant offset	: integer	:= ((c+KERNEL_W/2)*KERNEL_H + (r+KERNEL_H/2)) * 3*DATA_WIDTH_BITS;
	begin
		return unsigned(bus_data(offset+i*DATA_WIDTH_BITS+DATA_WIDTH_BITS-1 downto offset+i*DATA_WIDTH_BITS));
	end;

    signal valids		: std_logic_vector(TOTAL_DELAY-1 downto 0)		:= (others => '0');
	signal valid_o		: std_logic;
	signal run_en		: std_logic;

	signal g_pxl			: std_logic;
	signal r_row			: std_logic;
	signal col				: unsigned(IMAGE_WIDTH_BITS-1 downto 0);
	-- signal g_pxl_delayed	: std_logic;
	-- signal r_row_delayed	: std_logic;

	-- signal arr_grb_phase	: std_logic_vector(TOTAL_DELAY*2-1 downto 0) := (others => '0');
	signal arr_rb_raw		: std_logic_vector(TOTAL_DELAY*DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal rb_raw			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal green			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0) := (others => '0');
	signal dir				: std_logic		:= '0';

begin
	process(clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				g_pxl	<= g_init;
				r_row	<= rb_init;
				col		<= (others => '0');
			else
				if (ker_sdata_ready = '1') and (sdata_valid = '1') then
					if col = n_cols_in-1 then
						r_row <= not r_row;
						col <= (others => '0');
					else
						g_pxl <= not g_pxl;
						col <= col + 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	sdata_ready		<= ker_sdata_ready;
	ker_sdata_valid	<= sdata_valid and not(g_pxl);
	ker_sdata		<= sdata_gv & sdata_gh & sdata_raw;

	n_cols_div2		<= n_cols_in(n_cols_in'left downto 1);		-- store R/B pixels only

	kernel4decision_inst : entity work.kernel_top
		generic map
		(
			DATA_WIDTH_BITS		=> 3*DATA_WIDTH_BITS,
			IMAGE_WIDTH_BITS	=> IMAGE_WIDTH_BITS-1,
			IMAGE_HEIGHT_BITS	=> IMAGE_HEIGHT_BITS,
			MAX_IMAGE_WIDTH		=> MAX_IMAGE_WIDTH/2,
			KERNEL_H			=> KERNEL_H,
			KERNEL_W			=> KERNEL_W
		)
		port map
		(
			clk				=> clk,
			reset			=> reset,

			sdata			=> ker_sdata,
			sdata_valid		=> ker_sdata_valid,
			sdata_ready		=> ker_sdata_ready,

			mdata			=> ker_mdata,
			mdata_valid		=> ker_mdata_valid,
			mdata_ready		=> ker_mdata_ready,

			n_cols_in		=> n_cols_div2,
			n_rows_in		=> n_rows_in,
			n_cols_out		=> open,
			n_rows_out		=> open

		);




    ker_mdata_ready	<= run_en;
    valid_o			<= valids(valids'left);
	run_en			<= sync_sdata_ready or not(valid_o);

	decision_l : block

		constant GREEN_DELAY	: natural := 5;
		signal arr_ghv		: std_logic_vector(GREEN_DELAY*2*DATA_WIDTH_BITS-1 downto 0) := (others => '0');

		type g_t is array (0 to 12) of unsigned(DATA_WIDTH_BITS-1 downto 0);
		type rb_t is array (0 to 12) of unsigned(DATA_WIDTH_BITS-1 downto 0);
		type ch_t is array (0 to 12) of signed(DATA_WIDTH_BITS-0 downto 0);
		signal gh, gv			: g_t	:= (others => (others => '0'));
		signal rb				: rb_t	:= (others => (others => '0'));
		signal ch_h, ch_v		: ch_t	:= (others => (others => '0'));

		type d_tmp_t is array (0 to 7) of signed(DATA_WIDTH_BITS+1 downto 0);
		signal dh_tmp, dv_tmp	: d_tmp_t	:= (others => (others => '0'));
		type d_t is array (0 to 7) of unsigned(DATA_WIDTH_BITS-0 downto 0);
		signal dh, dv			: d_t	:= (others => (others => '0'));

		type d1_t is array (0 to 3) of unsigned(DATA_WIDTH_BITS+1 downto 0);
		signal d1h, d1v			: d1_t	:= (others => (others => '0'));

		type d2_t is array (0 to 1) of unsigned(DATA_WIDTH_BITS+2 downto 0);
		signal d2h, d2v			: d2_t	:= (others => (others => '0'));

		signal ddh, ddv				: unsigned(DATA_WIDTH_BITS+3 downto 0)		:= (others => '0');
		signal green_h, green_v		: std_logic_vector(DATA_WIDTH_BITS-1 downto 0)		:= (others => '0');

		signal g_pxl			: std_logic;
		signal r_row			: std_logic;
		signal col				: unsigned(IMAGE_WIDTH_BITS-1-1 downto 0):= (others => '0');

	begin
		process(clk)
		begin
			if rising_edge(clk) then
				if (reset = '1') then
					g_pxl	<= g_init;
					r_row	<= rb_init;
					col		<= (others => '0');
				else
					if (ker_mdata_valid = '1') and (ker_mdata_ready = '1') then
						if col = n_cols_div2-1 then
							r_row <= not r_row;
							g_pxl <= not g_pxl;		-- this should be there cause two columns are combined in one
							col <= (others => '0');
						else
							-- g_pxl <= not g_pxl;
							col <= col + 1;
						end if;
					end if;
				end if;
			end if;
		end process;

		rb(0)	<= data(-2,-1, 0, ker_mdata);
		rb(1)	<= data(-2, 0, 0, ker_mdata);
		rb(2)	<= data(-2, 1, 0, ker_mdata);
		rb(3)	<= data(-1,-1, 0, ker_mdata) when g_pxl = '1' else data(-1, 0, 0, ker_mdata);
		rb(4)	<= data(-1, 0, 0, ker_mdata) when g_pxl = '1' else data(-1, 1, 0, ker_mdata);
		rb(5)	<= data(-0,-1, 0, ker_mdata);
		rb(6)	<= data(-0, 0, 0, ker_mdata);
		rb(7)	<= data(-0, 1, 0, ker_mdata);
		rb(8)	<= data( 1,-1, 0, ker_mdata) when g_pxl = '1' else data( 1, 0, 0, ker_mdata);
		rb(9)	<= data( 1, 0, 0, ker_mdata) when g_pxl = '1' else data( 1, 1, 0, ker_mdata);
		rb(10)	<= data( 2,-1, 0, ker_mdata);
		rb(11)	<= data( 2, 0, 0, ker_mdata);
		rb(12)	<= data( 2, 1, 0, ker_mdata);

		gh(0)	<= data(-2,-1, 1, ker_mdata);
		gh(1)	<= data(-2, 0, 1, ker_mdata);
		gh(2)	<= data(-2, 1, 1, ker_mdata);
		gh(3)	<= data(-1,-1, 1, ker_mdata) when g_pxl = '1' else data(-1, 0, 1, ker_mdata);
		gh(4)	<= data(-1, 0, 1, ker_mdata) when g_pxl = '1' else data(-1, 1, 1, ker_mdata);
		gh(5)	<= data(-0,-1, 1, ker_mdata);
		gh(6)	<= data(-0, 0, 1, ker_mdata);
		gh(7)	<= data(-0, 1, 1, ker_mdata);
		gh(8)	<= data( 1,-1, 1, ker_mdata) when g_pxl = '1' else data( 1, 0, 1, ker_mdata);
		gh(9)	<= data( 1, 0, 1, ker_mdata) when g_pxl = '1' else data( 1, 1, 1, ker_mdata);
		gh(10)	<= data( 2,-1, 1, ker_mdata);
		gh(11)	<= data( 2, 0, 1, ker_mdata);
		gh(12)	<= data( 2, 1, 1, ker_mdata);

		gv(0)	<= data(-2,-1, 2, ker_mdata);
		gv(1)	<= data(-2, 0, 2, ker_mdata);
		gv(2)	<= data(-2, 1, 2, ker_mdata);
		gv(3)	<= data(-1,-1, 2, ker_mdata) when g_pxl = '1' else data(-1, 0, 2, ker_mdata);
		gv(4)	<= data(-1, 0, 2, ker_mdata) when g_pxl = '1' else data(-1, 1, 2, ker_mdata);
		gv(5)	<= data(-0,-1, 2, ker_mdata);
		gv(6)	<= data(-0, 0, 2, ker_mdata);
		gv(7)	<= data(-0, 1, 2, ker_mdata);
		gv(8)	<= data( 1,-1, 2, ker_mdata) when g_pxl = '1' else data( 1, 0, 2, ker_mdata);
		gv(9)	<= data( 1, 0, 2, ker_mdata) when g_pxl = '1' else data( 1, 1, 2, ker_mdata);
		gv(10)	<= data( 2,-1, 2, ker_mdata);
		gv(11)	<= data( 2, 0, 2, ker_mdata);
		gv(12)	<= data( 2, 1, 2, ker_mdata);

		-- step 1
		calc_ch :
		for i in 0 to 12 generate
			process(clk)
			begin
				if rising_edge(clk) then
					if (run_en = '1') then
						ch_h(i) <= signed('0'&rb(i)) - signed('0'&gh(i));
						ch_v(i) <= signed('0'&rb(i)) - signed('0'&gv(i));
					end if;
				end if;
			end process;
		end generate;

		dh_tmp(0)	<= resize(ch_h(0), dh_tmp(0)'length) - resize(ch_h(1), dh_tmp(0)'length);
		dh_tmp(1)	<= resize(ch_h(1), dh_tmp(0)'length) - resize(ch_h(2), dh_tmp(0)'length);
		dh_tmp(2)	<= resize(ch_h(3), dh_tmp(0)'length) - resize(ch_h(4), dh_tmp(0)'length);
		dh_tmp(3)	<= resize(ch_h(5), dh_tmp(0)'length) - resize(ch_h(6), dh_tmp(0)'length);
		dh_tmp(4)	<= resize(ch_h(6), dh_tmp(0)'length) - resize(ch_h(7), dh_tmp(0)'length);
		dh_tmp(5)	<= resize(ch_h(8), dh_tmp(0)'length) - resize(ch_h(9), dh_tmp(0)'length);
		dh_tmp(6)	<= resize(ch_h(10), dh_tmp(0)'length) - resize(ch_h(11), dh_tmp(0)'length);
		dh_tmp(7)	<= resize(ch_h(11), dh_tmp(0)'length) - resize(ch_h(12), dh_tmp(0)'length);

		dv_tmp(0)	<= resize(ch_v(0), dh_tmp(0)'length) - resize(ch_v(5), dh_tmp(0)'length);
		dv_tmp(1)	<= resize(ch_v(1), dh_tmp(0)'length) - resize(ch_v(6), dh_tmp(0)'length);
		dv_tmp(2)	<= resize(ch_v(2), dh_tmp(0)'length) - resize(ch_v(7), dh_tmp(0)'length);
		dv_tmp(3)	<= resize(ch_v(3), dh_tmp(0)'length) - resize(ch_v(8), dh_tmp(0)'length);
		dv_tmp(4)	<= resize(ch_v(4), dh_tmp(0)'length) - resize(ch_v(9), dh_tmp(0)'length);
		dv_tmp(5)	<= resize(ch_v(5), dh_tmp(0)'length) - resize(ch_v(10), dh_tmp(0)'length);
		dv_tmp(6)	<= resize(ch_v(6), dh_tmp(0)'length) - resize(ch_v(11), dh_tmp(0)'length);
		dv_tmp(7)	<= resize(ch_v(7), dh_tmp(0)'length) - resize(ch_v(12), dh_tmp(0)'length);

		-- step 2
		calc_d :
		for i in 0 to 7 generate
			process(clk)
			begin
				if rising_edge(clk) then
					if (run_en = '1') then
						dh(i) <= resize(unsigned(abs(dh_tmp(i))), dh(i)'length);
						dv(i) <= resize(unsigned(abs(dv_tmp(i))), dv(i)'length);
					end if;
				end if;
			end process;
		end generate;

		-- step 3
		calc_d1 :
		for i in 0 to 3 generate
			process(clk)
			begin
				if rising_edge(clk) then
					if (run_en = '1') then
						d1h(i) <= unsigned('0'&dh(2*i)) + unsigned('0'&dh(2*i+1));
						d1v(i) <= unsigned('0'&dv(2*i)) + unsigned('0'&dv(2*i+1));
					end if;
				end if;
			end process;
		end generate;

		-- step 4
		calc_d2 :
		for i in 0 to 1 generate
			process(clk)
			begin
				if rising_edge(clk) then
					if (run_en = '1') then
						d2h(i) <=  unsigned('0'&d1h(2*i)) +  unsigned('0'&d1h(2*i+1));
						d2v(i) <=  unsigned('0'&d1v(2*i)) +  unsigned('0'&d1v(2*i+1));
					end if;
				end if;
			end process;
		end generate;

		-- step 5
		process(clk)
		begin
			if rising_edge(clk) then
				if (run_en = '1') then
					ddh <=  unsigned('0'&d2h(0)) +  unsigned('0'&d2h(1));
					ddv <=  unsigned('0'&d2v(0)) +  unsigned('0'&d2v(1));

					arr_ghv <= arr_ghv((GREEN_DELAY-1)*2*DATA_WIDTH_BITS-1 downto 0) & std_logic_vector(gv(6))&std_logic_vector(gh(6));
				end if;
			end if;
		end process;

		green_v	<= arr_ghv(arr_ghv'left downto arr_ghv'left-DATA_WIDTH_BITS+1);
		green_h	<= arr_ghv(arr_ghv'left-DATA_WIDTH_BITS downto arr_ghv'left-2*DATA_WIDTH_BITS+1);

		-- step 6
		process(clk)
		begin
			if rising_edge(clk) then
				if (run_en = '1') then
					if (ddh < ddv) then
						green <= std_logic_vector(green_h);
						dir <= '0';
					else
						green <= std_logic_vector(green_v);
						dir <= '1';
					end if;
				end if;
			end if;
		end process;
	end block;

	process(clk)
	begin
		if rising_edge(clk) then
			if (run_en = '1') then
				arr_rb_raw <= arr_rb_raw((TOTAL_DELAY-1)*DATA_WIDTH_BITS-1 downto 0) & std_logic_vector(data(-0, 0, 0, ker_mdata));
				-- arr_grb_phase <= arr_grb_phase((TOTAL_DELAY-1)*2-1 downto 0) & g_pxl&r_row;
			end if;
		end if;
	end process;

	rb_raw			<= arr_rb_raw(arr_rb_raw'left downto arr_rb_raw'left-DATA_WIDTH_BITS+1);
	-- g_pxl_delayed	<= arr_grb_phase(arr_grb_phase'left);
	-- r_row_delayed	<= arr_grb_phase(arr_grb_phase'left-1);

	sync_sdata_valid	<= valid_o;

	sync_sdata			<= dir & green & rb_raw;
	fifo_sdata			<= sdata_raw;
	fifo_sdata_valid	<= sdata_valid and g_pxl;
	fifo_sdata_ready	<= ker_sdata_ready;

	data_synchronizer_inst : entity work.data_synchronizer
		generic map
		(
			DATA1_WIDTH			=> 2*DATA_WIDTH_BITS+1,
			DATA2_WIDTH			=> DATA_WIDTH_BITS,
			FIFO_SIZE_BITS		=> IMAGE_WIDTH_BITS + 1
		)
		port map
		(
			clk				=> clk,
			reset			=> reset,

			s1data			=> sync_sdata,
			s1data_valid	=> sync_sdata_valid,
			s1data_ready	=> sync_sdata_ready,

			s2data			=> fifo_sdata,
			s2data_valid	=> fifo_sdata_valid,
			s2data_ready	=> fifo_sdata_ready,

			m1data			=> sync_m1data,
			m2data			=> sync_m2data,
			mdata_valid		=> sync_mdata_valid,
			mdata_ready		=> sync_mdata_ready
		);

		mdata_dir			<= sync_m1data(sync_m1data'left);
		mdata_g				<= sync_m1data(2*DATA_WIDTH_BITS-1 downto DATA_WIDTH_BITS);
		mdata_rb_orig		<= sync_m1data(DATA_WIDTH_BITS-1 downto 0);
		mdata_g_orig		<= sync_m2data;

		mdata_valid			<= sync_mdata_valid;
		sync_mdata_ready	<= mdata_ready;

	process(clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				valids	<= (others =>'0');
			else
				if (run_en = '1') then
					valids <= valids(valids'left-1 downto 0) & ker_mdata_valid;
				end if;
			end if;
		end if;
	end process;

end architecture IMPL;
