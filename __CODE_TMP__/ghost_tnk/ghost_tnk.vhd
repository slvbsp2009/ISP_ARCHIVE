library ieee, work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ghost_tnk is
	generic
	(
		PXL_IN_WIDTH		: natural	:= 10;
		PXL_IN_NUM			: natural	:= 9;

		PXL_OUT_WIDTH		: natural	:= 10;
		PXL_OUT_NUM			: natural	:= 1;

		TNK_PXL_NUM			: natural	:= 9;

		GHOST_COEF_NORM		: natural	:= 10
	);
	port
	(
		clk			: in std_logic;
		reset		: in std_logic;

		sdata		: in std_logic_vector(PXL_IN_WIDTH*PXL_IN_NUM-1 downto 0);
		sdata_valid	: in std_logic;
		sdata_ready	: out std_logic;

		mdata		: out std_logic_vector(PXL_OUT_WIDTH*PXL_OUT_NUM-1 downto 0);
		mdata_valid	: out std_logic;
		mdata_ready	: in std_logic;

		coef		: in std_logic_vector(GHOST_COEF_NORM-1 downto 0);

		th0			: in std_logic_vector(7 downto 0);
		th1			: in std_logic_vector(7 downto 0);
		th2			: in std_logic_vector(7 downto 0);
		th3			: in std_logic_vector(7 downto 0);
		th4			: in std_logic_vector(7 downto 0);
		th5			: in std_logic_vector(7 downto 0);
		th6			: in std_logic_vector(7 downto 0);
		th7			: in std_logic_vector(7 downto 0);
		th8			: in std_logic_vector(7 downto 0);
		th9			: in std_logic_vector(7 downto 0);
		th10		: in std_logic_vector(7 downto 0);
		th11		: in std_logic_vector(7 downto 0);
		th12		: in std_logic_vector(7 downto 0);
		th13		: in std_logic_vector(7 downto 0);
		th14		: in std_logic_vector(7 downto 0)
	);
end ghost_tnk;

architecture Behavioral of ghost_tnk is


	signal ghost_sdata_ready		: std_logic;
	signal ghost_mdata_bus			: std_logic_vector(TNK_PXL_NUM*PXL_OUT_WIDTH-1 downto 0);
	signal ghost_mdata_valid		: std_logic;
	signal ghost_mdata_ready		: std_logic;

	signal tnk_sdata			: std_logic_vector(TNK_PXL_NUM*PXL_OUT_WIDTH-1 downto 0);
	signal tnk_sdata_valid		: std_logic;
	signal tnk_sdata_ready		: std_logic;

begin
	sdata_ready		<= ghost_sdata_ready;

	GHOST_remover_inst : entity work.ghost_remover
		generic map
		(
			DATA_IN_WIDTH	=> PXL_OUT_WIDTH,
			PIXEL_CNT		=> TNK_PXL_NUM
		)
		port map
		(
			clk				=> clk,
			reset			=> reset,

			sdata			=> sdata,
			sdata_valid		=> sdata_valid,
			sdata_ready		=> ghost_sdata_ready,

			mdata			=> ghost_mdata_bus,
			mdata_valid		=> ghost_mdata_valid,
			mdata_ready		=> ghost_mdata_ready,

			coef			=> coef
		);

	ghost_mdata_ready	<= tnk_sdata_ready;
	tnk_sdata_valid		<= ghost_mdata_valid;

		-- put current pixel to first position [0] and previous to last one
		-- tnk_sdata[0] = ghost_mdata_bus: [0][8][7][6][5][4][3][2][1]
		-- tnk_sdata[1] = ghost_mdata_bus: [1][0][8][7][6][5][4][3][2]
	tnk_sdata		<= ghost_mdata_bus((3+1)*PXL_OUT_WIDTH-1 downto 0) &
					   ghost_mdata_bus(TNK_PXL_NUM*PXL_OUT_WIDTH-1 downto (3+1)*PXL_OUT_WIDTH);

	TNK_inst : entity work.TNK
		generic map
		(
			DATA_IN_WIDTH	=> PXL_OUT_WIDTH,
			PIXEL_CNT		=> TNK_PXL_NUM,
			REG_INPUT		=> true
		)
		port map
		(
			clk				=> clk,
			reset			=> reset,

			pxls_in			=> tnk_sdata,			-- sdata
			tr_ready		=> tnk_sdata_valid, 	-- sdata_valid
			input_ready		=> tnk_sdata_ready,		-- sdata_ready

			data_out		=> mdata,		-- mdata
			data_out_en		=> mdata_valid,	-- mdata_vallid
			re_ready		=> mdata_ready,	-- mdata_ready

			th0				=> th0,
			th1				=> th1,
			th2				=> th2,
			th3				=> th3,
			th4				=> th4,
			th5				=> th5,
			th6				=> th6,
			th7				=> th7,
			th8				=> th8,
			th9				=> th9,
			th10			=> th10,
			th11			=> th11,
			th12			=> th12,
			th13			=> th13,
			th14			=> th14,
			dynamic			=> '1',

			imageWidth	=> (others => '0'),
			average_DC	=> '0'

		);

end Behavioral;
