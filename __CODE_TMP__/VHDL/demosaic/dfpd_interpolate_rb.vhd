library ieee, work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dfpd_interpolate_rb is
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

		sdata_dir		: in std_logic;	-- 0- hor; 1- vert
		sdata_g			: in std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		sdata_g_orig	: in std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		sdata_rb_orig	: in std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		sdata_valid		: in std_logic;
		sdata_ready		: out std_logic;

		mdata_r			: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_g			: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_b			: out std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
		mdata_valid		: out std_logic;
		mdata_ready		: in std_logic;

		n_cols_in		: in unsigned(IMAGE_WIDTH_BITS-1 downto 0);
		n_rows_in		: in unsigned(IMAGE_HEIGHT_BITS-1 downto 0);

		db_en			: in std_logic;
		g_init			: in std_logic;
		rb_init			: in std_logic

	);
end dfpd_interpolate_rb;


architecture IMPL of dfpd_interpolate_rb is

	signal n_cols_div2			: unsigned(IMAGE_WIDTH_BITS-2 downto 0);

	signal sdata_ready_o		: std_logic;

	signal phase1_mdata_b_on_g		: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase1_mdata_r_on_g		: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase1_mdata_g_orig		: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase1_mdata_c_orig		: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase1_mdata_g_on_c		: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase1_mdata_valid		: std_logic;
	signal phase1_mdata_ready		: std_logic;
	signal phase1_r_row				: std_logic;

	signal phase2_mdata_a_orig		: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase2_mdata_a_on_g		: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase2_mdata_b_on_g		: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase2_mdata_b_on_a		: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase2_mdata_g_orig		: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase2_mdata_g_on_c		: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase2_mdata_valid		: std_logic;
	signal phase2_mdata_ready		: std_logic;
	signal phase2_mdata_r_row		: std_logic;
	signal phase2_mdata_g_pxl		: std_logic;

	signal phase3_mdata_r			: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase3_mdata_g			: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase3_mdata_b			: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
	signal phase3_mdata_valid		: std_logic;
	signal phase3_mdata_ready		: std_logic;



begin

	n_cols_div2		<= n_cols_in(n_cols_in'left downto 1);		-- store R/B pixels only
	sdata_ready		<= sdata_ready_o;

	interp_rb_on_g : block
		constant KERNEL_H		: natural	:= 3;
		constant KERNEL_W		: natural	:= 3;
		constant TOTAL_DELAY	: natural 	:= 3;

		impure
		function data(r,c,i:integer; bus_data:std_logic_vector) return unsigned is
			constant offset	: integer	:= ((c+KERNEL_W/2)*KERNEL_H + (r+KERNEL_H/2)) * 2*DATA_WIDTH_BITS;
		begin
			return unsigned(bus_data(offset+i*DATA_WIDTH_BITS+DATA_WIDTH_BITS-1 downto offset+i*DATA_WIDTH_BITS));
		end;

	    signal valids		: std_logic_vector(TOTAL_DELAY-1 downto 0)		:= (others => '0');
		signal valid_o		: std_logic;
		signal run_en		: std_logic;

		signal ker_sdata			: std_logic_vector(2*DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal ker_sdata_valid		: std_logic;
		signal ker_sdata_ready		: std_logic;
		signal ker_mdata			: std_logic_vector(KERNEL_H*KERNEL_W*2*DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal ker_mdata_valid		: std_logic;
		signal ker_mdata_ready		: std_logic;

		signal sync_sdata			: std_logic_vector(KERNEL_H*KERNEL_W*2*DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal sync_sdata_valid		: std_logic;
		signal sync_sdata_ready		: std_logic;

		signal fifo_sdata			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal fifo_sdata_valid		: std_logic;
		signal fifo_sdata_ready		: std_logic;

		signal sync_m1data			: std_logic_vector(KERNEL_H*KERNEL_W*2*DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal sync_m2data			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal sync_mdata_valid		: std_logic;
		signal sync_mdata_ready		: std_logic;

		signal g_pxl			: std_logic;
		signal r_row			: std_logic;
		signal col				: unsigned(IMAGE_WIDTH_BITS-1-1 downto 0):= (others => '0');

		signal g_pxl_c1, r_row_c1			: std_logic;
		signal g_pxl_c2, r_row_c2			: std_logic;
		signal g_pxl_c3, r_row_c3			: std_logic;

		signal cv0, cv2, ch0, ch2	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal gv0, gv2, gh0, gh2	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal g11					: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal sum_gh, sum_gv		: signed(DATA_WIDTH_BITS+1 downto 0)	:= (others => '0');
		signal sum_ch, sum_cv		: unsigned(DATA_WIDTH_BITS-0 downto 0)	:= (others => '0');
		signal ch_tmp, cv_tmp		: signed(DATA_WIDTH_BITS+2 downto 0)	:= (others => '0');
		signal r_tmp, b_tmp			: std_logic_vector(DATA_WIDTH_BITS+2 downto 0)	:= (others => '0');
		signal b_on_g				: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal r_on_g				: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');

		signal g11_c1, g11_c2, g11_c3	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal g_int_c1, g_int_c2, g_int_c3	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal c_orig_c1, c_orig_c2, c_orig_c3	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');

		-- type test_t is array (0 to KERNEL_H-1, 0 to KERNEL_W-1) of unsigned(DATA_WIDTH_BITS-1 downto 0);
		-- signal test_g, test_rb_orig		: test_t;
	begin
		sdata_ready_o		<= ker_sdata_ready;
		ker_sdata_valid		<= sdata_valid;
		ker_sdata			<= sdata_g & sdata_rb_orig;

		kerne_int_rb_on_g_inst : entity work.kernel_top
			generic map
			(
				DATA_WIDTH_BITS		=> 2*DATA_WIDTH_BITS,
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

		ker_mdata_ready		<= sync_sdata_ready;
		sync_sdata			<= ker_mdata;
		sync_sdata_valid	<= ker_mdata_valid;
		fifo_sdata			<= sdata_g_orig;
		fifo_sdata_valid	<= ker_sdata_valid;
		fifo_sdata_ready	<= ker_sdata_ready;

		data_synchronizer_inst : entity work.data_synchronizer
			generic map
			(
				DATA1_WIDTH			=> KERNEL_H*KERNEL_W*2*DATA_WIDTH_BITS,
				DATA2_WIDTH			=> DATA_WIDTH_BITS,
				FIFO_SIZE_BITS		=> IMAGE_WIDTH_BITS
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

		process(clk)
		begin
			if rising_edge(clk) then
				if (reset = '1') then
					g_pxl	<= g_init;
					r_row	<= rb_init;
					col		<= (others => '0');
					valids	<= (others =>'0');
				else
					if (sync_mdata_ready = '1') and (sync_mdata_valid = '1') then
						if col = n_cols_div2-1 then
							r_row <= not r_row;
							g_pxl <= not g_pxl;		-- this should be there cause two columns are combined in one
							col <= (others => '0');
						else
							-- g_pxl <= not g_pxl;
							col <= col + 1;
						end if;
					end if;
					if (run_en = '1') then
						valids <= valids(valids'left-1 downto 0) & sync_mdata_valid;
					end if;
				end if;
			end if;
		end process;


		sync_mdata_ready	<= run_en;
	    valid_o				<= valids(valids'left);
		run_en				<= phase1_mdata_ready or not(valid_o);

		gv0	<= data(-1,0, 1, sync_m1data);
		gv2	<= data(+1,0, 1, sync_m1data);
		gh0	<= data( 0,0, 1, sync_m1data);
		gh2	<= data(0,-1, 1, sync_m1data) when g_pxl = '0' else
			   data(0,+1, 1, sync_m1data);

		cv0	<= data(-1,0, 0, sync_m1data);
		cv2	<= data(+1,0, 0, sync_m1data);
		ch0	<= data( 0,0, 0, sync_m1data);
		ch2	<= data(0,-1, 0, sync_m1data) when g_pxl = '0' else
			   data(0,+1, 0, sync_m1data);

		g11 <= unsigned(sync_m2data);

		r_tmp	<= std_logic_vector(ch_tmp) when r_row_c2 = '1' else std_logic_vector(cv_tmp);
		b_tmp	<= std_logic_vector(cv_tmp) when r_row_c2 = '1' else std_logic_vector(ch_tmp);

		process(clk)
		begin
			if rising_edge(clk) then
				if (run_en = '1') then
					-- step 1
					g_pxl_c1 <= g_pxl;
					r_row_c1 <= r_row;
					g11_c1 <= g11;
					c_orig_c1 <= data( 0,0, 0, sync_m1data);
					g_int_c1 <= data( 0,0, 1, sync_m1data);
					sum_gh <= signed('0'&g11&'0') - signed("00"&gh0) - signed("00"&gh2);
					sum_gv <= signed('0'&g11&'0') - signed("00"&gv0) - signed("00"&gv2);
					sum_ch <= unsigned('0'&ch0) + unsigned('0'&ch2);
					sum_cv <= unsigned('0'&cv0) + unsigned('0'&cv2);

					-- step 2
					g_pxl_c2 <= g_pxl_c1;
					r_row_c2 <= r_row_c1;
					g11_c2 <= g11_c1;
					c_orig_c2 <= c_orig_c1;
					g_int_c2 <= g_int_c1;
					ch_tmp <= resize(sum_gh, ch_tmp'length) + signed("00"&sum_ch);
					cv_tmp <= resize(sum_gv, cv_tmp'length) + signed("00"&sum_cv);

					-- step 3
					g_pxl_c3 <= g_pxl_c2;
					r_row_c3 <= r_row_c2;
					g11_c3 <= g11_c2;
					c_orig_c3 <= c_orig_c2;
					g_int_c3 <= g_int_c2;
					-- red
					if (r_tmp(r_tmp'left) = '1') then
						r_on_g <= (others => '0');
					elsif (r_tmp(r_tmp'left-1) = '1') then
						r_on_g <= (others => '1');
					else
						r_on_g <= unsigned(r_tmp(DATA_WIDTH_BITS downto 1));
					end if;
					-- blue
					if (b_tmp(b_tmp'left) = '1') then
						b_on_g <= (others => '0');
					elsif (b_tmp(b_tmp'left-1) = '1') then
						b_on_g <= (others => '1');
					else
						b_on_g <= unsigned(b_tmp(DATA_WIDTH_BITS downto 1));
					end if;
				end if;
			end if;
		end process;

-- gr:
--     for r in  0 to KERNEL_H-1 generate
--     gc:
--         for c in 0 to KERNEL_W-1 generate
-- 			test_g(r,c)			<= data(r-1,c-1, 1, sync_m1data);
-- 			test_rb_orig(r,c)	<= data(r-1,c-1, 0, sync_m1data);
--     	   end generate;
-- 		end generate;
--
		phase1_mdata_b_on_g	<= b_on_g;
		phase1_mdata_r_on_g	<= r_on_g;
		phase1_mdata_g_orig	<= g11_c3;
		phase1_mdata_c_orig	<= c_orig_c3;
		phase1_mdata_g_on_c	<= g_int_c3;
		phase1_mdata_valid	<= valid_o;
		phase1_r_row		<= r_row_c3;
    	-- phase1_mdata_ready	<= mdata_ready;

	end block ;

	interp_rb_on_c : block
		constant KERNEL_H		: natural	:= 3;
		constant KERNEL_W		: natural	:= 3;
		constant KER_DATA_WIDTH	: natural	:= 2*DATA_WIDTH_BITS;

		constant TOTAL_DELAY	: natural 	:= 3;
		impure
		function data(r,c,i:integer; bus_data:std_logic_vector) return unsigned is
			constant offset	: integer	:= ((c+KERNEL_W/2)*KERNEL_H + (r+KERNEL_H/2)) * KER_DATA_WIDTH;
		begin
			return unsigned(bus_data(offset+i*DATA_WIDTH_BITS+DATA_WIDTH_BITS-1 downto offset+i*DATA_WIDTH_BITS));
		end;

	    signal valids		: std_logic_vector(TOTAL_DELAY-1 downto 0)		:= (others => '0');
		signal valid_o		: std_logic;
		signal run_en		: std_logic;

		signal ker_sdata			: std_logic_vector(KER_DATA_WIDTH-1 downto 0)	:= (others => '0');
		signal ker_sdata_valid		: std_logic;
		signal ker_sdata_ready		: std_logic;
		signal ker_mdata			: std_logic_vector(KERNEL_H*KERNEL_W*KER_DATA_WIDTH-1 downto 0)	:= (others => '0');
		signal ker_mdata_valid		: std_logic;
		signal ker_mdata_ready		: std_logic;

		signal sync_sdata			: std_logic_vector(KERNEL_H*KERNEL_W*KER_DATA_WIDTH-1 downto 0)	:= (others => '0');
		signal sync_sdata_valid		: std_logic;
		signal sync_sdata_ready		: std_logic;
		signal fifo_sdata			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal fifo_sdata_valid		: std_logic;
		signal fifo_sdata_ready		: std_logic;
		signal sync_m1data			: std_logic_vector(KERNEL_H*KERNEL_W*KER_DATA_WIDTH-1 downto 0)	:= (others => '0');
		signal sync_m2data			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal sync_mdata_valid		: std_logic;
		signal sync_mdata_ready		: std_logic;

		signal sync1_sdata			: std_logic_vector(DATA_WIDTH_BITS+KERNEL_H*KERNEL_W*KER_DATA_WIDTH-1 downto 0)	:= (others => '0');
		signal sync1_sdata_valid	: std_logic;
		signal sync1_sdata_ready	: std_logic;
		signal fifo1_sdata			: std_logic_vector(1-1 downto 0)	:= (others => '0');
		signal fifo1_sdata_valid	: std_logic;
		signal fifo1_sdata_ready	: std_logic;
		signal sync1_m1data			: std_logic_vector(DATA_WIDTH_BITS+KERNEL_H*KERNEL_W*KER_DATA_WIDTH-1 downto 0)	:= (others => '0');
		signal sync1_m2data			: std_logic_vector(1-1 downto 0)	:= (others => '0');
		signal sync1_mdata_valid	: std_logic;
		signal sync1_mdata_ready	: std_logic;

		signal s_ker_data			: std_logic_vector(KERNEL_H*KERNEL_W*KER_DATA_WIDTH-1 downto 0)	:= (others => '0');
		signal s_orig_data			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal s_dir_data			: std_logic;

		signal g_pxl			: std_logic;
		signal r_row			: std_logic;
		signal col				: unsigned(IMAGE_WIDTH_BITS-1-1 downto 0):= (others => '0');

		signal a1, a0, b0, a2, b2	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal av0, av2				: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal ah0, ah2				: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal bv0, bv2				: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal bh0, bh2				: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal amb0, amb2	 		: signed(DATA_WIDTH_BITS+0 downto 0)	:= (others => '0');
		signal a1_c1, a1_c2, a1_c3	: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal a_on_g_c1, b_on_g_c1			: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal a_on_g_c2, b_on_g_c2			: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal a_on_g_c3, b_on_g_c3			: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal a_tmp				: signed(DATA_WIDTH_BITS+2 downto 0)	:= (others => '0');
		signal b_on_a				: unsigned(DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');

		signal fifo2_sdata			: std_logic_vector(2*DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal sync2_m2data			: std_logic_vector(2*DATA_WIDTH_BITS-1 downto 0)	:= (others => '0');
		signal sync2_sdata_valid	: std_logic;
		signal sync2_sdata_ready	: std_logic;
		signal sync2_mdata_valid	: std_logic;

	begin

		phase1_mdata_ready	<= ker_sdata_ready;
		ker_sdata_valid		<= phase1_mdata_valid;
		ker_sdata			<= std_logic_vector(phase1_mdata_b_on_g) & std_logic_vector(phase1_mdata_r_on_g) when phase1_r_row = '1' else
							   std_logic_vector(phase1_mdata_r_on_g) & std_logic_vector(phase1_mdata_b_on_g);

		kerne_int_rb_on_g_inst : entity work.kernel_top
			generic map
			(
				DATA_WIDTH_BITS		=> KER_DATA_WIDTH,
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

		ker_mdata_ready		<= sync_sdata_ready;
		sync_sdata			<= ker_mdata;
		sync_sdata_valid	<= ker_mdata_valid;
		fifo_sdata			<= std_logic_vector(phase1_mdata_c_orig);
		fifo_sdata_valid	<= ker_sdata_valid;
		fifo_sdata_ready	<= ker_sdata_ready;

		data_synchronizer_inst : entity work.data_synchronizer
			generic map
			(
				DATA1_WIDTH			=> KERNEL_H*KERNEL_W*KER_DATA_WIDTH,
				DATA2_WIDTH			=> DATA_WIDTH_BITS,
				FIFO_SIZE_BITS		=> IMAGE_WIDTH_BITS
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

		sync_mdata_ready	<= sync1_sdata_ready;
		sync1_sdata			<= sync_m2data & sync_m1data;
		sync1_sdata_valid	<= sync_mdata_valid;
		fifo1_sdata(0)		<= sdata_dir;
		fifo1_sdata_valid	<= sdata_valid;
		fifo1_sdata_ready	<= sdata_ready_o;

		dir_synchronizer_inst : entity work.data_synchronizer
			generic map
			(
				DATA1_WIDTH			=> DATA_WIDTH_BITS+KERNEL_H*KERNEL_W*KER_DATA_WIDTH,
				DATA2_WIDTH			=> 1,
				FIFO_SIZE_BITS		=> IMAGE_WIDTH_BITS
			)
			port map
			(
				clk				=> clk,
				reset			=> reset,

				s1data			=> sync1_sdata,
				s1data_valid	=> sync1_sdata_valid,
				s1data_ready	=> sync1_sdata_ready,

				s2data			=> fifo1_sdata,
				s2data_valid	=> fifo1_sdata_valid,
				s2data_ready	=> fifo1_sdata_ready,

				m1data			=> sync1_m1data,
				m2data			=> sync1_m2data,
				mdata_valid		=> sync1_mdata_valid,
				mdata_ready		=> sync1_mdata_ready
			);

		s_ker_data		<= sync1_m1data(KERNEL_H*KERNEL_W*KER_DATA_WIDTH-1 downto 0);
		s_orig_data		<= sync1_m1data(sync1_m1data'left downto KERNEL_H*KERNEL_W*KER_DATA_WIDTH);
		s_dir_data		<= sync1_m2data(0);

		process(clk)
		begin
			if rising_edge(clk) then
				if (reset = '1') then
					g_pxl	<= g_init;
					r_row	<= rb_init;
					col		<= (others => '0');
					valids	<= (others =>'0');
				else
					if (sync1_mdata_ready = '1') and (sync1_mdata_valid = '1') then
						if col = n_cols_div2-1 then
							r_row <= not r_row;
							g_pxl <= not g_pxl;		-- this should be there cause two columns are combined in one
							col <= (others => '0');
						else
							-- g_pxl <= not g_pxl;
							col <= col + 1;
						end if;
					end if;
					if (run_en = '1') then
						valids <= valids(valids'left-1 downto 0) & sync1_mdata_valid;
					end if;
				end if;
			end if;
		end process;

		sync1_mdata_ready	<= run_en;
	    valid_o				<= valids(valids'left);
		run_en				<= sync2_sdata_ready or not(valid_o);

		a1	<= unsigned(s_orig_data);

		ah0	<= data( 0,0, 0, s_ker_data) when g_pxl = '1' else data( 0,+1, 0, s_ker_data);
		ah2	<= data( 0,0, 0, s_ker_data) when g_pxl = '0' else data( 0,-1, 0, s_ker_data);
		av0	<= data(-1,0, 1, s_ker_data);
		av2	<= data(+1,0, 1, s_ker_data);
		bh0	<= data( 0,0, 1, s_ker_data) when g_pxl = '1' else data( 0,+1, 1, s_ker_data);
		bh2	<= data( 0,0, 1, s_ker_data) when g_pxl = '0' else data( 0,-1, 1, s_ker_data);
		bv0	<= data(-1,0, 0, s_ker_data);
		bv2	<= data(+1,0, 0, s_ker_data);

		a0 <= ah0 when s_dir_data = '0' else av0;
		a2 <= ah2 when s_dir_data = '0' else av2;
		b0 <= bh0 when s_dir_data = '0' else bv0;
		b2 <= bh2 when s_dir_data = '0' else bv2;

-- debug_i0 : block
-- 	signal row				: unsigned(IMAGE_HEIGHT_BITS-1 downto 0);
-- 	signal col				: unsigned(IMAGE_WIDTH_BITS-1 downto 0);
-- begin
-- 	process(clk)
-- 	begin
-- 		if rising_edge(clk) then
-- 			if (reset = '1') then
-- 				row		<= (others => '0');
-- 				col		<= (others => '0');
-- 			else
-- 				if (sync1_mdata_ready = '1') and (sync1_mdata_valid = '1') then
-- 					if col = n_cols_in/2-1 then
-- 						row <= row + 1;
-- 						col <= (others => '0');
-- 					else
-- 						col <= col + 1;
-- 					end if;
-- 				end if;
-- 			end if;
-- 		end if;
-- 	end process;
-- end block;

		process(clk)
		begin
			if rising_edge(clk) then
				if (run_en = '1') then
					-- step 1
					a1_c1 <= a1;
					amb0 <= signed('0'&b0) - signed('0'&a0);
					amb2 <= signed('0'&b2) - signed('0'&a2);

					-- step 2
					a1_c2 <= a1_c1;
					a_on_g_c2 <= a_on_g_c1;
					b_on_g_c2 <= b_on_g_c1;
					a_on_g_c1 <= data( 0,0, 0, s_ker_data);
					b_on_g_c1 <= data( 0,0, 1, s_ker_data);
					a_tmp <= signed("00"&a1_c1&'0') + resize(amb0, a_tmp'length) + resize(amb2, a_tmp'length);

					-- step 3
					a1_c3 <= a1_c2;
					a_on_g_c3 <= a_on_g_c2;
					b_on_g_c3 <= b_on_g_c2;
					if (a_tmp(a_tmp'left) = '1') then
						b_on_a <= (others => '0');
					elsif (a_tmp(a_tmp'left-1) = '1') then
						b_on_a <= (others => '1');
					else
						b_on_a <= unsigned(a_tmp(DATA_WIDTH_BITS downto 1));
					end if;
				end if;
			end if;
		end process;

		fifo2_sdata			<= std_logic_vector(phase1_mdata_g_on_c) & std_logic_vector(phase1_mdata_g_orig);
		sync2_sdata_valid	<= valid_o;

		green_synchronizer_inst : entity work.data_synchronizer
			generic map
			(
				DATA1_WIDTH			=> DATA_WIDTH_BITS,
				DATA2_WIDTH			=> 2*DATA_WIDTH_BITS,
				FIFO_SIZE_BITS		=> IMAGE_WIDTH_BITS
			)
			port map
			(
				clk				=> clk,
				reset			=> reset,

				s1data			=> (others => '0'),
				s1data_valid	=> sync2_sdata_valid,
				s1data_ready	=> sync2_sdata_ready,

				s2data			=> fifo2_sdata,
				s2data_valid	=> phase1_mdata_valid,
				s2data_ready	=> phase1_mdata_ready,

				m1data			=> open,
				m2data			=> sync2_m2data,
				mdata_valid		=> sync2_mdata_valid,
				mdata_ready		=> phase2_mdata_ready
			);

		phase2_mdata_a_orig		<= a1_c3;
		phase2_mdata_a_on_g		<= a_on_g_c3 when db_en = '1' else phase2_mdata_g_orig;
		phase2_mdata_b_on_g		<= b_on_g_c3 when db_en = '1' else phase2_mdata_g_orig;
		phase2_mdata_b_on_a		<= b_on_a when db_en = '1' else phase2_mdata_a_orig;
		phase2_mdata_g_orig		<= unsigned(sync2_m2data(DATA_WIDTH_BITS-1 downto 0));
		phase2_mdata_g_on_c		<= unsigned(sync2_m2data(2*DATA_WIDTH_BITS-1 downto DATA_WIDTH_BITS)) when db_en = '1' else phase2_mdata_a_orig;
		phase2_mdata_valid		<= sync2_mdata_valid;

	end block;

	gen_rgb : block
		signal g_pxl		: std_logic;
		signal r_row		: std_logic;
		signal col			: unsigned(IMAGE_WIDTH_BITS-1 downto 0):= (others => '0');
	    signal valids		: std_logic_vector(1-1 downto 0)		:= (others => '0');
		signal run_en		: std_logic;
	begin
    	phase2_mdata_ready	<= run_en and col(0);
		run_en				<= phase3_mdata_ready or not(phase3_mdata_valid);
	    phase3_mdata_valid	<= valids(valids'left);

		process(clk)
		begin
			if rising_edge(clk) then
				if (reset = '1') then
					g_pxl	<= g_init;
					r_row	<= rb_init;
					col		<= (others => '0');
					valids	<= (others =>'0');
				else
					if (run_en = '1') and (phase2_mdata_valid = '1') then
						if col = n_cols_in-1 then
							r_row <= not r_row;
							col <= (others => '0');
						else
							g_pxl <= not g_pxl;
							col <= col + 1;
						end if;
					end if;
					if (run_en = '1') then
						valids(0) <= phase2_mdata_valid;
						if (g_pxl = '1') and (r_row = '1') then		-- green_r
							phase3_mdata_r <= phase2_mdata_a_on_g;
							phase3_mdata_g <= phase2_mdata_g_orig;
							phase3_mdata_b <= phase2_mdata_b_on_g;
						elsif (g_pxl = '0') and (r_row = '1') then	-- red
							phase3_mdata_r <= phase2_mdata_a_orig;
							phase3_mdata_g <= phase2_mdata_g_on_c;
							phase3_mdata_b <= phase2_mdata_b_on_a;
						elsif (g_pxl = '1') and (r_row = '0') then	-- green_b
							phase3_mdata_r <= phase2_mdata_b_on_g;
							phase3_mdata_g <= phase2_mdata_g_orig;
							phase3_mdata_b <= phase2_mdata_a_on_g;
						else 										-- blue
							phase3_mdata_r <= phase2_mdata_b_on_a;
							phase3_mdata_g <= phase2_mdata_g_on_c;
							phase3_mdata_b <= phase2_mdata_a_orig;
						end if;
					end if;
				end if;
			end if;
		end process;

	end block;

	mdata_r				<= std_logic_vector(phase3_mdata_r);
	mdata_g				<= std_logic_vector(phase3_mdata_g);
	mdata_b				<= std_logic_vector(phase3_mdata_b);
	mdata_valid			<= phase3_mdata_valid;
	phase3_mdata_ready	<= mdata_ready;

end architecture IMPL;
