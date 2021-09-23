library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- use work.pipe_pkg.all;
-- use work.shared_components.all;

entity pipe_debayering_wpad is
	generic
	(
		DATA_WIDTH_BITS		: natural := 10;
		IMAGE_WIDTH_BITS	: natural; -- := 12;
		IMAGE_HEIGHT_BITS	: natural; -- := 11;
		MAX_IMAGE_WIDTH		: natural;
		PAD_Y				: natural := 4;
		PAD_X				: natural := 4

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
end pipe_debayering_wpad;

architecture a1 of pipe_debayering_wpad is

	-- signal pad_n_cols_in				: n_cols;
	-- signal pad_n_cols_out				: n_cols;
	signal pad_n_cols_in					: unsigned(IMAGE_WIDTH_BITS-1 downto 0);
	signal pad_n_rows_in					: unsigned(IMAGE_HEIGHT_BITS-1 downto 0);
	signal pad_n_cols_out					: unsigned(IMAGE_WIDTH_BITS-1 downto 0);
	signal pad_n_rows_out					: unsigned(IMAGE_HEIGHT_BITS-1 downto 0);
	signal pad_data_in						: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal pad_data_in_valid				: std_logic;
	signal pad_data_in_ready				: std_logic;
	signal pad_data_out						: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal pad_data_out_valid				: std_logic;
	signal pad_data_out_ready				: std_logic;

	-- signal db_n_cols_in				: n_cols;
	-- signal db_n_cols_out				: n_cols;
	signal db_n_cols_in						: unsigned(IMAGE_WIDTH_BITS-1 downto 0);
	signal db_n_rows_in						: unsigned(IMAGE_HEIGHT_BITS-1 downto 0);
	signal db_n_cols_out					: unsigned(IMAGE_WIDTH_BITS-1 downto 0);
	signal db_n_rows_out					: unsigned(IMAGE_HEIGHT_BITS-1 downto 0);
	signal db_data_in						: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal db_data_in_valid					: std_logic;
	signal db_data_in_ready					: std_logic;
	signal db_data_r_out					: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal db_data_g_out					: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal db_data_b_out					: std_logic_vector(DATA_WIDTH_BITS-1 downto 0);
	signal db_data_out_valid				: std_logic;
	signal db_data_out_ready				: std_logic;

	-- signal crop_n_cols_in				: n_cols;
	-- signal crop_n_cols_out			: n_cols;
	signal crop_n_cols_in					: unsigned(IMAGE_WIDTH_BITS-1 downto 0);
	signal crop_n_rows_in					: unsigned(IMAGE_HEIGHT_BITS-1 downto 0);
	signal crop_n_cols_out					: unsigned(IMAGE_WIDTH_BITS-1 downto 0);
	signal crop_n_rows_out					: unsigned(IMAGE_HEIGHT_BITS-1 downto 0);
	signal crop_data_in						: std_logic_vector(3*DATA_WIDTH_BITS-1 downto 0);
	signal crop_data_in_valid				: std_logic;
	signal crop_data_in_ready				: std_logic;
	signal crop_data_out					: std_logic_vector(3*DATA_WIDTH_BITS-1 downto 0);
	signal crop_data_out_valid				: std_logic;
	signal crop_data_out_ready				: std_logic;

begin

	pad_n_cols_in			<= n_cols_in;
	pad_n_rows_in			<= n_rows_in;
	pad_data_in				<= sdata;
	pad_data_in_valid		<= sdata_valid;
	sdata_ready				<= pad_data_in_ready;

	PAD_inst : entity work.pipe_bayer_pad
		generic map
		(
			DATA_WIDTH_BITS		=> DATA_WIDTH_BITS,
			IMAGE_WIDTH_BITS	=> IMAGE_WIDTH_BITS,
			IMAGE_HEIGHT_BITS	=> IMAGE_HEIGHT_BITS,
			PAD_Y				=> PAD_Y,
			PAD_X				=> PAD_X
		)
		port map
		(
			clk				=> clk,
			reset			=> reset,

			sdata			=> pad_data_in,
			sdata_valid		=> pad_data_in_valid,
			sdata_ready		=> pad_data_in_ready,

			mdata			=> pad_data_out,
			mdata_valid		=> pad_data_out_valid,
			mdata_ready		=> pad_data_out_ready,

			-- params_in		=> pad_n_cols_in,
			-- params_out		=> pad_n_cols_out
			n_cols_in		=> pad_n_cols_in,
			n_rows_in		=> pad_n_rows_in,
			n_cols_out		=> pad_n_cols_out,
			n_rows_out		=> pad_n_rows_out
		);


	db_n_cols_in			<= pad_n_cols_out;
	db_n_rows_in			<= pad_n_rows_out;
	db_data_in				<= pad_data_out;
	db_data_in_valid		<= pad_data_out_valid;
	pad_data_out_ready		<= db_data_in_ready;

	DB_inst : entity work.pipe_debayering
		generic map
		(
			DATA_WIDTH_BITS		=> DATA_WIDTH_BITS,
			IMAGE_WIDTH_BITS	=> IMAGE_WIDTH_BITS,
			IMAGE_HEIGHT_BITS	=> IMAGE_HEIGHT_BITS,
			MAX_IMAGE_WIDTH		=> MAX_IMAGE_WIDTH
		)
		port map
		(
			clk				=> clk,
			reset			=> reset,

			sdata			=> db_data_in,
			sdata_valid		=> db_data_in_valid,
			sdata_ready		=> db_data_in_ready,

			mdata_r			=> db_data_r_out,
			mdata_g			=> db_data_g_out,
			mdata_b			=> db_data_b_out,
			mdata_valid		=> db_data_out_valid,
			mdata_ready		=> db_data_out_ready,

			-- params_in		=> db_n_cols_in,
			-- params_out		=> db_n_cols_out,
			n_cols_in		=> db_n_cols_in,
			n_rows_in		=> db_n_rows_in,
			n_cols_out		=> db_n_cols_out,
			n_rows_out		=> db_n_rows_out,

			db_en			=> db_en,
			shift_R			=> shift_R,
			shift_C			=> shift_C
		);

	crop_n_cols_in			<= db_n_cols_out;
	crop_n_rows_in			<= db_n_rows_out;
	crop_data_in			<= db_data_b_out&db_data_g_out&db_data_r_out;
	crop_data_in_valid		<= db_data_out_valid;
	db_data_out_ready		<= crop_data_in_ready;

	CROP_inst : entity work.pipe_crop
		generic map
		(
			DATA_WIDTH			=> DATA_WIDTH_BITS*3,
			IMAGE_WIDTH_BITS	=> IMAGE_WIDTH_BITS,
			IMAGE_HEIGHT_BITS	=> IMAGE_HEIGHT_BITS

			-- CROP_LEFT			=> 2,
			-- CROP_RIGHT			=> 2,
			-- CROP_TOP			=> 2,
			-- CROP_BOTTOM			=> 2
		)
		port map
		(
			clk				=> clk,
			reset			=> reset,

			sdata			=> crop_data_in,
			sdata_valid		=> crop_data_in_valid,
			sdata_ready		=> crop_data_in_ready,

			mdata			=> crop_data_out,
			mdata_valid		=> crop_data_out_valid,
			mdata_ready		=> crop_data_out_ready,

			crop_left		=> std_logic_vector(to_unsigned(PAD_X, IMAGE_WIDTH_BITS)),
			crop_right		=> std_logic_vector(to_unsigned(PAD_X, IMAGE_WIDTH_BITS)),
			crop_top		=> std_logic_vector(to_unsigned(PAD_Y, IMAGE_HEIGHT_BITS)),
			crop_bottom		=> std_logic_vector(to_unsigned(PAD_Y, IMAGE_HEIGHT_BITS)),

			n_cols_in		=> crop_n_cols_in,
			n_rows_in		=> crop_n_rows_in,
			n_cols_out		=> crop_n_cols_out,
			n_rows_out		=> crop_n_rows_out
		);

	n_cols_out			<= crop_n_cols_out;
	n_rows_out			<= crop_n_rows_out;
	mdata_r				<= crop_data_out(1*DATA_WIDTH_BITS-1 downto 0*DATA_WIDTH_BITS);
	mdata_g				<= crop_data_out(2*DATA_WIDTH_BITS-1 downto 1*DATA_WIDTH_BITS);
	mdata_b				<= crop_data_out(3*DATA_WIDTH_BITS-1 downto 2*DATA_WIDTH_BITS);
	mdata_valid			<= crop_data_out_valid;
	crop_data_out_ready		<= mdata_ready;

end a1;
