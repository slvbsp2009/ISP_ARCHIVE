library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pipe_pkg.all;

entity pipe_debayering is
	generic
	(
		DATA_WIDTH_BITS	: natural := 10;
		IMAGE_WIDTH_BITS	: natural := 12;
		IMAGE_HEIGHT_BITS	: natural := 11;
		MAX_IMAGE_WIDTH		: natural;
		KERNEL_H			: natural := 7;
		KERNEL_W			: natural := 7;
		REG_INPUT			: boolean	:= true
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
		shift_R			: in std_logic;
		shift_C			: in std_logic

	);
end pipe_debayering;

architecture a1 of pipe_debayering is

	signal sdata_reg			: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal sdata_valid_reg		: std_logic;
	signal sdata_ready_reg		: std_logic;

	signal ker_data				: std_logic_vector(KERNEL_H*KERNEL_W*DATA_WIDTH_BITS-1 downto 0);
	signal ker_data_valid		: std_logic;
	signal ker_data_ready		: std_logic;
	signal ker_n_cols_out		: unsigned(IMAGE_WIDTH_BITS-1 downto 0);
	signal ker_n_rows_out		: unsigned(IMAGE_HEIGHT_BITS-1 downto 0);

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

			sdata			=> sdata_reg,
			sdata_valid		=> sdata_valid_reg,
			sdata_ready		=> sdata_ready_reg,

			mdata			=> ker_data,
			mdata_valid		=> ker_data_valid,
			mdata_ready		=> ker_data_ready,

			n_cols_in		=> n_cols_in,
			n_rows_in		=> n_rows_in,
			n_cols_out		=> ker_n_cols_out,
			n_rows_out		=> ker_n_rows_out

		);

	db_inst : entity work.debayering
		generic map
		(
			DATA_WIDTH_BITS		=> DATA_WIDTH_BITS,
			IMAGE_WIDTH_BITS	=> IMAGE_WIDTH_BITS,
			IMAGE_HEIGHT_BITS	=> IMAGE_HEIGHT_BITS,
			KERNEL_H			=> KERNEL_H,
			KERNEL_W			=> KERNEL_W
		)
		port map
		(
			clk				=> clk,
			reset			=> reset,

			sdata			=> ker_data,
			sdata_valid		=> ker_data_valid,
			sdata_ready		=> ker_data_ready,

			mdata_r			=> mdata_r,
			mdata_g			=> mdata_g,
			mdata_b			=> mdata_b,
			mdata_valid		=> mdata_valid,
			mdata_ready		=> mdata_ready,

			n_cols_in		=> ker_n_cols_out,
			n_rows_in		=> ker_n_rows_out,
			n_cols_out		=> n_cols_out,
			n_rows_out		=> n_rows_out,

			db_en			=> db_en,
			shift_R			=> shift_R,
			shift_C			=> shift_C
		);

end a1;
