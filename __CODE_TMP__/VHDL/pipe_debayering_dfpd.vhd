library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pipe_pkg.all;

entity pipe_debayering_dfpd is
	generic
	(
		DATA_WIDTH_BITS		: natural;-- := 10;
		IMAGE_WIDTH_BITS	: natural;-- := 12;
		IMAGE_HEIGHT_BITS	: natural;-- := 11;
		MAX_IMAGE_WIDTH		: natural;-- := 2368;
		REG_INPUT			: boolean := true
	);
	port
	(
		clk				: in std_logic;
		reset			: in std_logic;

		sdata			: in std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
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
		g_init			: in std_logic;
		rb_init			: in std_logic

	);
end pipe_debayering_dfpd;

architecture a1 of pipe_debayering_dfpd is

	signal sdata_reg			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal sdata_valid_reg		: std_logic;
	signal sdata_ready_reg		: std_logic;

	signal ghv_mdata_gv			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal ghv_mdata_gh			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal ghv_mdata_raw		: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal ghv_mdata_valid		: std_logic;
	signal ghv_mdata_ready		: std_logic;

	signal dir_mdata_dir		: std_logic;	-- 0- hor; 1- vert
	signal dir_mdata_g			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal dir_mdata_g_orig		: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal dir_mdata_rb_orig	: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal dir_mdata_valid		: std_logic;
	signal dir_mdata_ready		: std_logic;

	signal rb_mdata_r			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal rb_mdata_g			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal rb_mdata_b			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal rb_mdata_valid		: std_logic;
	signal rb_mdata_ready		: std_logic;

begin

	L_noreg:
	if not(REG_INPUT) generate
		sdata_reg				<= sdata;
		sdata_valid_reg			<= sdata_valid;
		sdata_ready				<= sdata_ready_reg;
	end generate;

	L_reg:
	if (REG_INPUT) generate
		axiStreamConnector_inst : entity work.axiStreamConnector
			generic map
			(
				DATA_IN_WIDTH	=> DATA_WIDTH_BITS
			)
			port map
			(
				clk			=> clk,
				reset		=> reset,

				s_data			=> sdata,
				s_data_valid	=> sdata_valid,
				s_data_ready	=> sdata_ready,
				m_data			=> sdata_reg,
				m_data_valid	=> sdata_valid_reg,
				m_data_ready	=> sdata_ready_reg
			);
	end generate;

	n_cols_out <= n_cols_in;
	n_rows_out <= n_rows_in;

	-- =========================================================================
	-- estimate Gh/Gv in 5x5 window
	gh_gv_module : entity work.dfpd_get_greens_hv
		generic map
		(
			DATA_WIDTH_BITS		=> DATA_WIDTH_BITS,
			IMAGE_WIDTH_BITS	=> IMAGE_WIDTH_BITS,
			IMAGE_HEIGHT_BITS	=> IMAGE_HEIGHT_BITS,
			MAX_IMAGE_WIDTH		=> MAX_IMAGE_WIDTH,

			KERNEL_H			=> 5,
			KERNEL_W			=> 5
		)
		port map
		(
			clk			=> clk,
			reset		=> reset,

			sdata			=> sdata_reg,
			sdata_valid		=> sdata_valid_reg,
			sdata_ready		=> sdata_ready_reg,

			mdata_gh		=> ghv_mdata_gv,
			mdata_gv		=> ghv_mdata_gh,
			mdata_raw		=> ghv_mdata_raw,
			mdata_valid		=> ghv_mdata_valid,
			mdata_ready		=> ghv_mdata_ready,

			n_cols_in		=> n_cols_in,
			n_rows_in		=> n_rows_in
		);

	decision_module : entity work.dfpd_decision
		generic map
		(
			DATA_WIDTH_BITS		=> DATA_WIDTH_BITS,
			IMAGE_WIDTH_BITS	=> IMAGE_WIDTH_BITS,
			IMAGE_HEIGHT_BITS	=> IMAGE_HEIGHT_BITS,
			MAX_IMAGE_WIDTH		=> MAX_IMAGE_WIDTH
		)
		port map
		(
			clk			=> clk,
			reset		=> reset,

			sdata_gh		=> ghv_mdata_gv,
			sdata_gv		=> ghv_mdata_gh,
			sdata_raw		=> ghv_mdata_raw,
			sdata_valid		=> ghv_mdata_valid,
			sdata_ready		=> ghv_mdata_ready,

			mdata_dir		=> dir_mdata_dir,
			mdata_g			=> dir_mdata_g,
			mdata_g_orig	=> dir_mdata_g_orig,
			mdata_rb_orig	=> dir_mdata_rb_orig,
			mdata_valid		=> dir_mdata_valid,
			mdata_ready		=> dir_mdata_ready,

			n_cols_in		=> n_cols_in,
			n_rows_in		=> n_rows_in,
			g_init			=> g_init,
			rb_init			=> rb_init
		);

-- debug
-- debug_i : block
-- 	signal row				: unsigned(IMAGE_HEIGHT_BITS-1 downto 0);
-- 	signal col				: unsigned(IMAGE_WIDTH_BITS-1 downto 0);
-- 	signal n_cols_div2			: unsigned(IMAGE_WIDTH_BITS-2 downto 0);
-- begin
-- 	n_cols_div2		<= n_cols_in(n_cols_in'left downto 1);		-- store R/B pixels only
-- 	process(clk)
-- 	begin
-- 		if rising_edge(clk) then
-- 			if (reset = '1') then
-- 				row		<= (others => '0');
-- 				col		<= (others => '0');
-- 			else
-- 				if (dir_mdata_ready = '1') and (dir_mdata_valid = '1') then
-- 					if col = n_cols_div2-1 then
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

	interp_rb_module :  entity work.dfpd_interpolate_rb
		generic map
		(
			DATA_WIDTH_BITS		=> DATA_WIDTH_BITS,
			IMAGE_WIDTH_BITS	=> IMAGE_WIDTH_BITS,
			IMAGE_HEIGHT_BITS	=> IMAGE_HEIGHT_BITS,
			MAX_IMAGE_WIDTH		=> MAX_IMAGE_WIDTH
		)
		port map
		(
			clk			=> clk,
			reset		=> reset,

			sdata_dir		=> dir_mdata_dir,
			sdata_g			=> dir_mdata_g,
			sdata_g_orig	=> dir_mdata_g_orig,
			sdata_rb_orig	=> dir_mdata_rb_orig,
			sdata_valid		=> dir_mdata_valid,
			sdata_ready		=> dir_mdata_ready,

			mdata_r			=> rb_mdata_r,
			mdata_g			=> rb_mdata_g,
			mdata_b			=> rb_mdata_b,
			mdata_valid		=> rb_mdata_valid,
			mdata_ready		=> rb_mdata_ready,

			n_cols_in		=> n_cols_in,
			n_rows_in		=> n_rows_in,
			db_en			=> db_en,
			g_init			=> g_init,
			rb_init			=> rb_init
		);

	mdata_r			<= rb_mdata_r;
	mdata_g			<= rb_mdata_g;
	mdata_b			<= rb_mdata_b;
	mdata_valid		<= rb_mdata_valid;
	rb_mdata_ready	<= mdata_ready;

end a1;
