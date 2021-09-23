library ieee, work, std;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity TNK is
	generic
	(
		CHIPSCOPE_EN		: integer := 0;

		DATA_IN_WIDTH		: integer := 10;
		PIXEL_CNT			: integer := 9;		-- 9,7,5 or 3
		DC_NUM				: integer := 32;

		TOTAL_DELAY_BITS	: integer := 8;
		WEIGHT_WIDTH		: integer := 4;
		MULT_DELAY			: integer := 3;
		REG_INPUT			: boolean := true

	);
	port
	(
		clk			: in  std_logic;
		reset		: in  std_logic;
		tr_ready	: in  std_logic;
		re_ready	: in  std_logic;
		pxls_in		: in  std_logic_vector(DATA_IN_WIDTH*PIXEL_CNT-1 downto 0);

		th0			: in  std_logic_vector(7 downto 0);
		th1			: in  std_logic_vector(7 downto 0);
		th2			: in  std_logic_vector(7 downto 0);
		th3			: in  std_logic_vector(7 downto 0);
		th4			: in  std_logic_vector(7 downto 0);
		th5			: in  std_logic_vector(7 downto 0);
		th6			: in  std_logic_vector(7 downto 0);
		th7			: in  std_logic_vector(7 downto 0);
		th8			: in  std_logic_vector(7 downto 0);
		th9			: in  std_logic_vector(7 downto 0);
		th10		: in  std_logic_vector(7 downto 0);
		th11		: in  std_logic_vector(7 downto 0);
		th12		: in  std_logic_vector(7 downto 0);
		th13		: in  std_logic_vector(7 downto 0);
		th14		: in  std_logic_vector(7 downto 0);
		dynamic		: in std_logic;

		imageWidth	: in  std_logic_vector(11 downto 0);	-- input image width
		average_DC	: in std_logic;

		-- tnk_frame_addr_p			: in std_logic_vector(27 * 9 - 1 downto 0);
		-- tnk_dump_step_p				: in std_logic_vector(3 * 9 - 1 downto 0);
		-- tnk_initial_skip_p			: in std_logic_vector(10 * 9 - 1 downto 0);

		input_ready	: out  std_logic;
		data_out	: out  std_logic_vector(DATA_IN_WIDTH-1 downto 0);
		data_out_en	: out  std_logic
	);
end TNK;

architecture Behavioral of TNK is

	component delay_vector_en is
		generic
		(
			delay	: Integer := 1;
			msb		: Integer := 3
		);
		port
		(
			clk   : in     std_logic;
			d_in  : in     std_logic_vector(msb downto 0);
			d_out : out    std_logic_vector(msb downto 0);
			en    : in     std_logic;
			reset : in     std_logic
		);
	end component delay_vector_en;
	component uuMULT is
		generic
		(
			A_BITS 	: integer := 8;
			B_BITS 	: integer := 8;
			PIPE	: integer := 4
		);
		port
		(
			clk:	in std_logic;
			a:		in std_logic_vector(A_BITS-1 downto 0);
			b:		in std_logic_vector(B_BITS-1 downto 0);
			ce:		in std_logic;
			c: 		out std_logic_vector(A_BITS+B_BITS-1 downto 0)
		);
	end component uuMULT;
	component uudiv19_9
	  port (
	    aclk : in std_logic;
    	aclken : in std_logic;
	    s_axis_divisor_tvalid : in std_logic;
	    s_axis_divisor_tdata : in std_logic_vector(15 downto 0);
	    s_axis_dividend_tvalid : in std_logic;
	    s_axis_dividend_tdata : in std_logic_vector(23 downto 0);
	    m_axis_dout_tvalid : out std_logic;
	    m_axis_dout_tdata : out std_logic_vector(39 downto 0)
	  );
	end component;

-- ============== CHIPSCOPE =======================================

	-- component icon_2
	  -- PORT (
		-- CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		-- CONTROL1 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
	-- end component;
	-- component ila_128
	  -- PORT (
		-- CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		-- CLK : IN STD_LOGIC;
		-- TRIG0 : IN STD_LOGIC_VECTOR(127 DOWNTO 0));
	-- end component;
	-- component vio_380
	  -- PORT (
		-- CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		-- CLK : IN STD_LOGIC;
		-- ASYNC_IN : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
		-- SYNC_IN : IN STD_LOGIC_VECTOR(255 DOWNTO 0));
	-- end component;

	-- signal CONTROL0 : STD_LOGIC_VECTOR(35 DOWNTO 0);
	-- signal CONTROL1 : STD_LOGIC_VECTOR(35 DOWNTO 0);
	-- signal ASYNC_IN : STD_LOGIC_VECTOR(255 DOWNTO 0);
	-- signal SYNC_IN : STD_LOGIC_VECTOR(255 DOWNTO 0);
	-- signal TRIG0 : STD_LOGIC_VECTOR(127 DOWNTO 0);

-- ================================================================

	constant	tnk_delay : integer := MULT_DELAY + 27 + PIXEL_CNT/8 + (DATA_IN_WIDTH-10);

	type  	distans 		is array (PIXEL_CNT-1 downto 1) of std_logic_vector (DATA_IN_WIDTH downto 0);
	type	w1_type			is array (PIXEL_CNT-1 downto 1) of std_logic_vector (14 downto 0);
	type	weight_type		is array (PIXEL_CNT-1 downto 0) of std_logic_vector (WEIGHT_WIDTH-1 downto 0);
	type	weights8_type 	is array ((PIXEL_CNT-1)/8 downto 1) of std_logic_vector (WEIGHT_WIDTH+2 downto 0);
	type	data_in_type	is array (PIXEL_CNT-1 downto 0) of std_logic_vector (DATA_IN_WIDTH-1 downto 0);
	type	weightedPixel_type	is array (PIXEL_CNT-1 downto 0) of std_logic_vector (DATA_IN_WIDTH+WEIGHT_WIDTH-1 downto 0);
	type	weightedPixel4_type	is array ((PIXEL_CNT-1)/4 downto 1) of std_logic_vector (DATA_IN_WIDTH+WEIGHT_WIDTH+1 downto 0);
	type	weightedPixel8_type	is array ((PIXEL_CNT-1)/8 downto 1) of std_logic_vector (DATA_IN_WIDTH+WEIGHT_WIDTH+2 downto 0);

	signal	dist_abs:			distans;
	signal	TH0_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH1_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH2_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH3_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH4_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH5_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH6_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH7_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH8_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH9_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH10_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH11_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH12_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH13_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');
	signal	TH14_tmp:			std_logic_VECTOR(7 downto 0)	:= (others => '0');

	signal	TH0_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH1_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH2_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH3_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH4_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH5_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH6_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH7_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH8_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH9_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH10_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH11_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH12_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH13_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);
	signal	TH14_f:			std_logic_VECTOR(DATA_IN_WIDTH-1 downto 0);

	signal	w1:					w1_type;
	signal	w:					weight_type;
	signal	w8:					weights8_type;
	signal	data_in:			data_in_type;
	signal	data_in_d1:			data_in_type	:= (others => (others => '0'));
	signal	data_in_d2:			data_in_type;
	signal	data_in_d3:			data_in_type;
	signal	sumW, sumW_delayed:	std_logic_vector(WEIGHT_WIDTH+3 downto 0);
	signal	D_weighted:			weightedPixel_type;
	signal	Dw4:				weightedPixel4_type	:= (others => (others => '0'));
	signal	Dw8:				weightedPixel8_type	:= (others => (others => '0'));
	signal	Dw4_tmp:			std_logic_vector (DATA_IN_WIDTH+WEIGHT_WIDTH+1 downto 0)	:= (others => '0');
	signal	D0w_d1, D0w_d2:	 	std_logic_vector (DATA_IN_WIDTH+WEIGHT_WIDTH-1 downto 0)	:= (others => '0');
	signal	sumDxW:				std_logic_vector(DATA_IN_WIDTH+WEIGHT_WIDTH+3 downto 0)	:= (others => '0');
	signal	DxWdivW:			std_logic_VECTOR(DATA_IN_WIDTH+WEIGHT_WIDTH+4 downto 0)	:= (others => '0');

    signal s_axis_divisor_tdata		: std_logic_vector(15 downto 0);
    signal s_axis_dividend_tdata	: std_logic_vector(23 downto 0);
    signal m_axis_dout_tdata		: std_logic_vector(39 downto 0);

	signal	dividend:			std_logic_VECTOR(DATA_IN_WIDTH+WEIGHT_WIDTH+4 downto 0);
	signal	divisor:			std_logic_VECTOR(WEIGHT_WIDTH+4 downto 0);
	signal	reminder:			std_logic_VECTOR(WEIGHT_WIDTH+4 downto 0);
	signal 	col:				std_logic_vector(11 downto 0);
	signal 	dc, dc_d1:			std_logic;
	signal 	data_out_tmp:		std_logic_vector(DATA_IN_WIDTH-1 downto 0);

	signal run_en:				std_logic;
	signal data_ready_cnt:		std_logic_vector(TOTAL_DELAY_BITS-1 downto 0);
	signal data_ready:			std_logic;

	signal sdata_reg		: std_logic_vector(DATA_IN_WIDTH*PIXEL_CNT-1 downto 0);
	signal sdata_valid_reg	: std_logic;
	signal sdata_ready_reg	: std_logic;

begin

	L_noreg:
	if not(REG_INPUT) generate
		sdata_reg				<= pxls_in;
		sdata_valid_reg			<= tr_ready;
		input_ready				<= sdata_ready_reg;
	end generate;

	L_reg:
	if (REG_INPUT) generate
		axiStreamConnector_inst : entity work.axiStreamConnector
			generic map
			(
				DATA_IN_WIDTH	=> DATA_IN_WIDTH*PIXEL_CNT
			)
			port map
			(
				clk			=> clk,
				reset		=> reset,

				s_data			=> pxls_in,
				s_data_valid	=> tr_ready,
				s_data_ready	=> input_ready,
				m_data			=> sdata_reg,
				m_data_valid	=> sdata_valid_reg,
				m_data_ready	=> sdata_ready_reg
			);
	end generate;

	run_en 			<= sdata_valid_reg and re_ready;
	data_out_en		<= data_ready and sdata_valid_reg;
	sdata_ready_reg	<= re_ready;

L_assign: for i in 0 to PIXEL_CNT-1 GENERATE
	data_in(i) <= sdata_reg((i+1)*DATA_IN_WIDTH-1 downto i*DATA_IN_WIDTH);
END GENERATE L_assign;


	--================= TNK ==================
	process(clk)
		variable	TH0_1:			std_logic_VECTOR(7 downto 0);
		variable	TH1_1:			std_logic_VECTOR(7 downto 0);
		variable	TH2_1:			std_logic_VECTOR(7 downto 0);
		variable	TH3_1:			std_logic_VECTOR(7 downto 0);
		variable	TH4_1:			std_logic_VECTOR(7 downto 0);
		variable	TH5_1:			std_logic_VECTOR(7 downto 0);
		variable	TH6_1:			std_logic_VECTOR(7 downto 0);
		variable	TH7_1:			std_logic_VECTOR(7 downto 0);
		variable	TH8_1:			std_logic_VECTOR(7 downto 0);
		variable	TH9_1:			std_logic_VECTOR(7 downto 0);
		variable	TH10_1:			std_logic_VECTOR(7 downto 0);
		variable	TH11_1:			std_logic_VECTOR(7 downto 0);
		variable	TH12_1:			std_logic_VECTOR(7 downto 0);
		variable	TH13_1:			std_logic_VECTOR(7 downto 0);
		variable	TH14_1:			std_logic_VECTOR(7 downto 0);
		variable	TH0_2:			std_logic_VECTOR(7 downto 0);
		variable	TH1_2:			std_logic_VECTOR(7 downto 0);
		variable	TH2_2:			std_logic_VECTOR(7 downto 0);
		variable	TH3_2:			std_logic_VECTOR(7 downto 0);
		variable	TH4_2:			std_logic_VECTOR(7 downto 0);
		variable	TH5_2:			std_logic_VECTOR(7 downto 0);
		variable	TH6_2:			std_logic_VECTOR(7 downto 0);
		variable	TH7_2:			std_logic_VECTOR(7 downto 0);
		variable	TH8_2:			std_logic_VECTOR(7 downto 0);
		variable	TH9_2:			std_logic_VECTOR(7 downto 0);
		variable	TH10_2:			std_logic_VECTOR(7 downto 0);
		variable	TH11_2:			std_logic_VECTOR(7 downto 0);
		variable	TH12_2:			std_logic_VECTOR(7 downto 0);
		variable	TH13_2:			std_logic_VECTOR(7 downto 0);
		variable	TH14_2:			std_logic_VECTOR(7 downto 0);
	begin
		if clk'event and clk = '1' then
			-- if reset = '1' then
			-- 	TH0_tmp <=	(others => '0');
			-- 	TH1_tmp <=  (others => '0');
			-- 	TH2_tmp <=  (others => '0');
			-- 	TH3_tmp <=  (others => '0');
			-- 	TH4_tmp <=  (others => '0');
			-- 	TH5_tmp <=  (others => '0');
			-- 	TH6_tmp <=  (others => '0');
			-- 	TH7_tmp <=  (others => '0');
			-- 	TH8_tmp <=  (others => '0');
			-- 	TH9_tmp <=  (others => '0');
			-- 	TH10_tmp <= (others => '0');
			-- 	TH11_tmp <= (others => '0');
			-- 	TH12_tmp <= (others => '0');
			-- 	TH13_tmp <= (others => '0');
			-- 	TH14_tmp <= (others => '0');
			-- else
				if (data_in(0)(DATA_IN_WIDTH-1 downto DATA_IN_WIDTH-8) < 5) then
					TH0_1 := ext(TH0(7 downto 3), 8);	TH0_2 := ext(TH0(7 downto 3), 8);
					TH1_1 := ext(TH1(7 downto 3), 8);	TH1_2 := ext(TH1(7 downto 3), 8);
					TH2_1 := ext(TH2(7 downto 3), 8);	TH2_2 := ext(TH2(7 downto 3), 8);
					TH3_1 := ext(TH3(7 downto 3), 8);	TH3_2 := ext(TH3(7 downto 3), 8);
					TH4_1 := ext(TH4(7 downto 3), 8);	TH4_2 := ext(TH4(7 downto 3), 8);
					TH5_1 := ext(TH5(7 downto 3), 8);	TH5_2 := ext(TH5(7 downto 3), 8);
					TH6_1 := ext(TH6(7 downto 3), 8);	TH6_2 := ext(TH6(7 downto 3), 8);
					TH7_1 := ext(TH7(7 downto 3), 8);	TH7_2 := ext(TH7(7 downto 3), 8);
					TH8_1 := ext(TH8(7 downto 3), 8);	TH8_2 := ext(TH8(7 downto 3), 8);
					TH9_1 := ext(TH9(7 downto 3), 8);	TH9_2 := ext(TH9(7 downto 3), 8);
					TH10_1 := ext(TH10(7 downto 3), 8);	TH10_2 := ext(TH10(7 downto 3), 8);
					TH11_1 := ext(TH11(7 downto 3), 8);	TH11_2 := ext(TH11(7 downto 3), 8);
					TH12_1 := ext(TH12(7 downto 3), 8);	TH12_2 := ext(TH12(7 downto 3), 8);
					TH13_1 := ext(TH13(7 downto 3), 8);	TH13_2 := ext(TH13(7 downto 3), 8);
					TH14_1 := ext(TH14(7 downto 3), 8);	TH14_2 := ext(TH14(7 downto 3), 8);
				elsif (data_in(0)(DATA_IN_WIDTH-1 downto DATA_IN_WIDTH-8) < 10) then
					TH0_1 := ext(TH0(7 downto 2), 8);	TH0_2 := ext(TH0(7 downto 3), 8);
					TH1_1 := ext(TH1(7 downto 2), 8);	TH1_2 := ext(TH1(7 downto 3), 8);
					TH2_1 := ext(TH2(7 downto 2), 8);	TH2_2 := ext(TH2(7 downto 3), 8);
					TH3_1 := ext(TH3(7 downto 2), 8);	TH3_2 := ext(TH3(7 downto 3), 8);
					TH4_1 := ext(TH4(7 downto 2), 8);	TH4_2 := ext(TH4(7 downto 3), 8);
					TH5_1 := ext(TH5(7 downto 2), 8);	TH5_2 := ext(TH5(7 downto 3), 8);
					TH6_1 := ext(TH6(7 downto 2), 8);	TH6_2 := ext(TH6(7 downto 3), 8);
					TH7_1 := ext(TH7(7 downto 2), 8);	TH7_2 := ext(TH7(7 downto 3), 8);
					TH8_1 := ext(TH8(7 downto 2), 8);	TH8_2 := ext(TH8(7 downto 3), 8);
					TH9_1 := ext(TH9(7 downto 2), 8);	TH9_2 := ext(TH9(7 downto 3), 8);
					TH10_1 := ext(TH10(7 downto 2), 8);	TH10_2 := ext(TH10(7 downto 3), 8);
					TH11_1 := ext(TH11(7 downto 2), 8);	TH11_2 := ext(TH11(7 downto 3), 8);
					TH12_1 := ext(TH12(7 downto 2), 8);	TH12_2 := ext(TH12(7 downto 3), 8);
					TH13_1 := ext(TH13(7 downto 2), 8);	TH13_2 := ext(TH13(7 downto 3), 8);
					TH14_1 := ext(TH14(7 downto 2), 8);	TH14_2 := ext(TH14(7 downto 3), 8);
				elsif (data_in(0)(DATA_IN_WIDTH-1 downto DATA_IN_WIDTH-8) < 17) then
					TH0_1 := ext(TH0(7 downto 1), 8);	TH0_2 := (others => '0');
					TH1_1 := ext(TH1(7 downto 1), 8);	TH1_2 := (others => '0');
					TH2_1 := ext(TH2(7 downto 1), 8);	TH2_2 := (others => '0');
					TH3_1 := ext(TH3(7 downto 1), 8);	TH3_2 := (others => '0');
					TH4_1 := ext(TH4(7 downto 1), 8);	TH4_2 := (others => '0');
					TH5_1 := ext(TH5(7 downto 1), 8);	TH5_2 := (others => '0');
					TH6_1 := ext(TH6(7 downto 1), 8);	TH6_2 := (others => '0');
					TH7_1 := ext(TH7(7 downto 1), 8);	TH7_2 := (others => '0');
					TH8_1 := ext(TH8(7 downto 1), 8);	TH8_2 := (others => '0');
					TH9_1 := ext(TH9(7 downto 1), 8);	TH9_2 := (others => '0');
					TH10_1 := ext(TH10(7 downto 1), 8);	TH10_2 := (others => '0');
					TH11_1 := ext(TH11(7 downto 1), 8);	TH11_2 := (others => '0');
					TH12_1 := ext(TH12(7 downto 1), 8);	TH12_2 := (others => '0');
					TH13_1 := ext(TH13(7 downto 1), 8);	TH13_2 := (others => '0');
					TH14_1 := ext(TH14(7 downto 1), 8);	TH14_2 := (others => '0');
				elsif (data_in(0)(DATA_IN_WIDTH-1 downto DATA_IN_WIDTH-8) < 26) then
					TH0_1 := ext(TH0(7 downto 1), 8);	TH0_2 := ext(TH0(7 downto 3), 8);
					TH1_1 := ext(TH1(7 downto 1), 8);	TH1_2 := ext(TH1(7 downto 3), 8);
					TH2_1 := ext(TH2(7 downto 1), 8);	TH2_2 := ext(TH2(7 downto 3), 8);
					TH3_1 := ext(TH3(7 downto 1), 8);	TH3_2 := ext(TH3(7 downto 3), 8);
					TH4_1 := ext(TH4(7 downto 1), 8);	TH4_2 := ext(TH4(7 downto 3), 8);
					TH5_1 := ext(TH5(7 downto 1), 8);	TH5_2 := ext(TH5(7 downto 3), 8);
					TH6_1 := ext(TH6(7 downto 1), 8);	TH6_2 := ext(TH6(7 downto 3), 8);
					TH7_1 := ext(TH7(7 downto 1), 8);	TH7_2 := ext(TH7(7 downto 3), 8);
					TH8_1 := ext(TH8(7 downto 1), 8);	TH8_2 := ext(TH8(7 downto 3), 8);
					TH9_1 := ext(TH9(7 downto 1), 8);	TH9_2 := ext(TH9(7 downto 3), 8);
					TH10_1 := ext(TH10(7 downto 1), 8);	TH10_2 := ext(TH10(7 downto 3), 8);
					TH11_1 := ext(TH11(7 downto 1), 8);	TH11_2 := ext(TH11(7 downto 3), 8);
					TH12_1 := ext(TH12(7 downto 1), 8);	TH12_2 := ext(TH12(7 downto 3), 8);
					TH13_1 := ext(TH13(7 downto 1), 8);	TH13_2 := ext(TH13(7 downto 3), 8);
					TH14_1 := ext(TH14(7 downto 1), 8);	TH14_2 := ext(TH14(7 downto 3), 8);
				elsif (data_in(0)(DATA_IN_WIDTH-1 downto DATA_IN_WIDTH-8) < 40) then
					TH0_1 := ext(TH0(7 downto 1), 8);	TH0_2 := ext(TH0(7 downto 2), 8);
					TH1_1 := ext(TH1(7 downto 1), 8);	TH1_2 := ext(TH1(7 downto 2), 8);
					TH2_1 := ext(TH2(7 downto 1), 8);	TH2_2 := ext(TH2(7 downto 2), 8);
					TH3_1 := ext(TH3(7 downto 1), 8);	TH3_2 := ext(TH3(7 downto 2), 8);
					TH4_1 := ext(TH4(7 downto 1), 8);	TH4_2 := ext(TH4(7 downto 2), 8);
					TH5_1 := ext(TH5(7 downto 1), 8);	TH5_2 := ext(TH5(7 downto 2), 8);
					TH6_1 := ext(TH6(7 downto 1), 8);	TH6_2 := ext(TH6(7 downto 2), 8);
					TH7_1 := ext(TH7(7 downto 1), 8);	TH7_2 := ext(TH7(7 downto 2), 8);
					TH8_1 := ext(TH8(7 downto 1), 8);	TH8_2 := ext(TH8(7 downto 2), 8);
					TH9_1 := ext(TH9(7 downto 1), 8);	TH9_2 := ext(TH9(7 downto 2), 8);
					TH10_1 := ext(TH10(7 downto 1), 8);	TH10_2 := ext(TH10(7 downto 2), 8);
					TH11_1 := ext(TH11(7 downto 1), 8);	TH11_2 := ext(TH11(7 downto 2), 8);
					TH12_1 := ext(TH12(7 downto 1), 8);	TH12_2 := ext(TH12(7 downto 2), 8);
					TH13_1 := ext(TH13(7 downto 1), 8);	TH13_2 := ext(TH13(7 downto 2), 8);
					TH14_1 := ext(TH14(7 downto 1), 8);	TH14_2 := ext(TH14(7 downto 2), 8);
				elsif (data_in(0)(DATA_IN_WIDTH-1 downto DATA_IN_WIDTH-8) < 65) then
					TH0_1 := ext(TH0(7 downto 0), 8);	TH0_2 := (others => '0');
					TH1_1 := ext(TH1(7 downto 0), 8);	TH1_2 := (others => '0');
					TH2_1 := ext(TH2(7 downto 0), 8);	TH2_2 := (others => '0');
					TH3_1 := ext(TH3(7 downto 0), 8);	TH3_2 := (others => '0');
					TH4_1 := ext(TH4(7 downto 0), 8);	TH4_2 := (others => '0');
					TH5_1 := ext(TH5(7 downto 0), 8);	TH5_2 := (others => '0');
					TH6_1 := ext(TH6(7 downto 0), 8);	TH6_2 := (others => '0');
					TH7_1 := ext(TH7(7 downto 0), 8);	TH7_2 := (others => '0');
					TH8_1 := ext(TH8(7 downto 0), 8);	TH8_2 := (others => '0');
					TH9_1 := ext(TH9(7 downto 0), 8);	TH9_2 := (others => '0');
					TH10_1 := ext(TH10(7 downto 0), 8);	TH10_2 := (others => '0');
					TH11_1 := ext(TH11(7 downto 0), 8);	TH11_2 := (others => '0');
					TH12_1 := ext(TH12(7 downto 0), 8);	TH12_2 := (others => '0');
					TH13_1 := ext(TH13(7 downto 0), 8);	TH13_2 := (others => '0');
					TH14_1 := ext(TH14(7 downto 0), 8);	TH14_2 := (others => '0');
				else
					TH0_1 := ext(TH0(7 downto 0), 8);	TH0_2 := ext(TH0(7 downto 3), 8);
					TH1_1 := ext(TH1(7 downto 0), 8);	TH1_2 := ext(TH1(7 downto 3), 8);
					TH2_1 := ext(TH2(7 downto 0), 8);	TH2_2 := ext(TH2(7 downto 3), 8);
					TH3_1 := ext(TH3(7 downto 0), 8);	TH3_2 := ext(TH3(7 downto 3), 8);
					TH4_1 := ext(TH4(7 downto 0), 8);	TH4_2 := ext(TH4(7 downto 3), 8);
					TH5_1 := ext(TH5(7 downto 0), 8);	TH5_2 := ext(TH5(7 downto 3), 8);
					TH6_1 := ext(TH6(7 downto 0), 8);	TH6_2 := ext(TH6(7 downto 3), 8);
					TH7_1 := ext(TH7(7 downto 0), 8);	TH7_2 := ext(TH7(7 downto 3), 8);
					TH8_1 := ext(TH8(7 downto 0), 8);	TH8_2 := ext(TH8(7 downto 3), 8);
					TH9_1 := ext(TH9(7 downto 0), 8);	TH9_2 := ext(TH9(7 downto 3), 8);
					TH10_1 := ext(TH10(7 downto 0), 8);	TH10_2 := ext(TH10(7 downto 3), 8);
					TH11_1 := ext(TH11(7 downto 0), 8);	TH11_2 := ext(TH11(7 downto 3), 8);
					TH12_1 := ext(TH12(7 downto 0), 8);	TH12_2 := ext(TH12(7 downto 3), 8);
					TH13_1 := ext(TH13(7 downto 0), 8);	TH13_2 := ext(TH13(7 downto 3), 8);
					TH14_1 := ext(TH14(7 downto 0), 8);	TH14_2 := ext(TH14(7 downto 2), 8);
				end if;
				if (run_en = '1') then
					if (dynamic = '1') then
						TH0_tmp <=	TH0_1  + TH0_2 ;
						TH1_tmp <=  TH1_1  + TH1_2 ;
						TH2_tmp <=  TH2_1  + TH2_2 ;
						TH3_tmp <=  TH3_1  + TH3_2 ;
						TH4_tmp <=  TH4_1  + TH4_2 ;
						TH5_tmp <=  TH5_1  + TH5_2 ;
						TH6_tmp <=  TH6_1  + TH6_2 ;
						TH7_tmp <=  TH7_1  + TH7_2 ;
						TH8_tmp <=  TH8_1  + TH8_2 ;
						TH9_tmp <=  TH9_1  + TH9_2 ;
						TH10_tmp <=  TH10_1 + TH10_2;
						TH11_tmp <=  TH11_1 + TH11_2;
						TH12_tmp <=  TH12_1 + TH12_2;
						TH13_tmp <=  TH13_1 + TH13_2;
						TH14_tmp <=  TH14_1 + TH14_2;
					else
						TH0_tmp <=	TH0;
						TH1_tmp <=  TH1;
						TH2_tmp <=  TH2;
						TH3_tmp <=  TH3;
						TH4_tmp <=  TH4;
						TH5_tmp <=  TH5;
						TH6_tmp <=  TH6;
						TH7_tmp <=  TH7;
						TH8_tmp <=  TH8;
						TH9_tmp <=  TH9;
						TH10_tmp <=  TH10;
						TH11_tmp <=  TH11;
						TH12_tmp <=  TH12;
						TH13_tmp <=  TH13;
						TH14_tmp <=  TH14;
					end if;
				end if;
			-- end if;
		end if;
	end process;

	TH0_f		<= TH0_tmp & ext("00", DATA_IN_WIDTH - 8)  when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH1_f		<= TH1_tmp & ext("00", DATA_IN_WIDTH - 8)  when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH2_f		<= TH2_tmp & ext("00", DATA_IN_WIDTH - 8)  when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH3_f		<= TH3_tmp & ext("00", DATA_IN_WIDTH - 8)  when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH4_f		<= TH4_tmp & ext("00", DATA_IN_WIDTH - 8)  when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH5_f		<= TH5_tmp & ext("00", DATA_IN_WIDTH - 8)  when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH6_f		<= TH6_tmp & ext("00", DATA_IN_WIDTH - 8)  when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH7_f		<= TH7_tmp & ext("00", DATA_IN_WIDTH - 8)  when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH8_f		<= TH8_tmp & ext("00", DATA_IN_WIDTH - 8)  when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH9_f		<= TH9_tmp & ext("00", DATA_IN_WIDTH - 8)  when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH10_f		<= TH10_tmp & ext("00", DATA_IN_WIDTH - 8) when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH11_f		<= TH11_tmp & ext("00", DATA_IN_WIDTH - 8) when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH12_f		<= TH12_tmp & ext("00", DATA_IN_WIDTH - 8) when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH13_f		<= TH13_tmp & ext("00", DATA_IN_WIDTH - 8) when (dc_d1 = '0') or (average_DC = '0') else (others => '1');
	TH14_f		<= TH14_tmp & ext("00", DATA_IN_WIDTH - 8) when (dc_d1 = '0') or (average_DC = '0') else (others => '1');

	-- stage 1,2
	process(clk)
		type   		distans 	is array (PIXEL_CNT-1 downto 1) of std_logic_vector (DATA_IN_WIDTH downto 0);
		variable	dist:		distans;
	begin
		if clk'event and clk = '1' then
			if reset = '1' then
				w1 			<= (others => (others => '0'));
				dist_abs 	<= (others => (others => '0'));
			else
				if (run_en = '1') then
					for i in dist'range loop
						dist(i) := signed(ext(data_in(i), DATA_IN_WIDTH+1)) - signed(ext(data_in(0), DATA_IN_WIDTH+1));
					end loop;

					for i in dist'range loop
						if (dist(i)(DATA_IN_WIDTH) = '0') then
							dist_abs(i) <= dist(i);
						else
							dist_abs(i) <= not(dist(i)) + 1;
						end if;
					end loop;

					for i in w1'range loop
						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH0_f) then		w1(i)(0) <= '0';
						else														w1(i)(0) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH1_f) then		w1(i)(1) <= '0';
						else														w1(i)(1) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH2_f) then		w1(i)(2) <= '0';
						else														w1(i)(2) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH3_f) then		w1(i)(3) <= '0';
						else														w1(i)(3) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH4_f) then		w1(i)(4) <= '0';
						else														w1(i)(4) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH5_f) then		w1(i)(5) <= '0';
						else														w1(i)(5) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH6_f) then		w1(i)(6) <= '0';
						else														w1(i)(6) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH7_f) then		w1(i)(7) <= '0';
						else														w1(i)(7) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH8_f) then		w1(i)(8) <= '0';
						else														w1(i)(8) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH9_f) then		w1(i)(9) <= '0';
						else														w1(i)(9) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH10_f) then	w1(i)(10) <= '0';
						else														w1(i)(10) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH11_f) then 	w1(i)(11) <= '0';
						else														w1(i)(11) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH12_f) then 	w1(i)(12) <= '0';
						else														w1(i)(12) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH13_f) then 	w1(i)(13) <= '0';
						else														w1(i)(13) <= '1'; end if;

						if (dist_abs(i)(DATA_IN_WIDTH-1 downto 0) > TH14_f) then 	w1(i)(14) <= '0';
						else														w1(i)(14) <= '1'; end if;

					end loop;
				end if;
			end if;
		end if;
	end process;

	-- stage 3
	process(clk)
	begin
		if clk'event and clk = '1' then
			if reset = '1' then
				w			<= (others => (others => '0'));
				data_in_d1	<= (others => (others => '0'));
				data_in_d2	<= (others => (others => '0'));
				data_in_d3	<= (others => (others => '0'));
			else
				if (run_en = '1') then
					w(0) <= (others => '1');
					for i in 1 to PIXEL_CNT-1 loop
						w(i) <= ext('0'&w1(i)(0), WEIGHT_WIDTH) +
								ext('0'&w1(i)(1), WEIGHT_WIDTH) +
								ext('0'&w1(i)(2), WEIGHT_WIDTH) +
								ext('0'&w1(i)(3), WEIGHT_WIDTH) +
								ext('0'&w1(i)(4), WEIGHT_WIDTH) +
								ext('0'&w1(i)(5), WEIGHT_WIDTH) +
								ext('0'&w1(i)(6), WEIGHT_WIDTH) +
								ext('0'&w1(i)(7), WEIGHT_WIDTH) +
								ext('0'&w1(i)(8), WEIGHT_WIDTH) +
								ext('0'&w1(i)(9), WEIGHT_WIDTH) +
								ext('0'&w1(i)(10), WEIGHT_WIDTH) +
								ext('0'&w1(i)(11), WEIGHT_WIDTH) +
								ext('0'&w1(i)(12), WEIGHT_WIDTH) +
								ext('0'&w1(i)(13), WEIGHT_WIDTH) +
								ext('0'&w1(i)(14), WEIGHT_WIDTH);
					end loop;
					data_in_d1 <= data_in;
					data_in_d2 <= data_in_d1;
					data_in_d3 <= data_in_d2;
				end if;
			end if;
		end if;
	end process;

	-- stage 4,5,6
L_dataXweighted: for i in 0 to PIXEL_CNT-1 generate
	L_MULT_XxRevW : uuMULT
		generic map
		(
			A_BITS 	=> DATA_IN_WIDTH,
			B_BITS 	=> WEIGHT_WIDTH,
			PIPE	=> MULT_DELAY-1
		)
		port map
		(
			clk => clk,
			a => data_in_d3(i),
			b => w(i),
			ce => run_en,
			c => D_weighted(i)
		);
END GENERATE L_dataXweighted;

	-- stage 4,5
	process(clk)
	type   		weights2 	is array ((PIXEL_CNT-1)/2 downto 1) of std_logic_vector (WEIGHT_WIDTH-0 downto 0);
	type   		weights4 	is array ((PIXEL_CNT-1)/4 downto 1) of std_logic_vector (WEIGHT_WIDTH+1 downto 0);
	variable	w2:			weights2;
	variable	w4:			weights4;
	variable	w4_tmp:		std_logic_vector (WEIGHT_WIDTH+1 downto 0);
	begin
		if clk'event and clk = '1' then
			if reset = '1' then
				w8 <= (others => (others => '0'));
				sumW <= (others => '0');
			else
				if (run_en = '1') then
					if (PIXEL_CNT = 9) then
						for i in 1 to (PIXEL_CNT-1)/2 loop
							w2(i) := ext(w(2*i), WEIGHT_WIDTH+1) + ext(w(2*i-1), WEIGHT_WIDTH+1);
						end loop;
						for i in 1 to (PIXEL_CNT-1)/4 loop
							w4(i) := ext(w2(2*i), WEIGHT_WIDTH+2) + ext(w2(2*i-1), WEIGHT_WIDTH+2);
						end loop;
						for i in 1 to (PIXEL_CNT-1)/8 loop
							w8(i) <= ext(w4(2*i), WEIGHT_WIDTH+3) + ext(w4(2*i-1), WEIGHT_WIDTH+3);
						end loop;
						sumW <= ext(w8(1), WEIGHT_WIDTH+4) + ext(w(0), WEIGHT_WIDTH+4);		-- w(0) always (others=> '1')
					end if;
					if (PIXEL_CNT = 7) then
						for i in 1 to (PIXEL_CNT-1)/2 loop
							w2(i) := ext(w(2*i), WEIGHT_WIDTH+1) + ext(w(2*i-1), WEIGHT_WIDTH+1);
						end loop;
						for i in 1 to (PIXEL_CNT-1)/4 loop
							w4(i) := ext(w2(2*i), WEIGHT_WIDTH+2) + ext(w2(2*i-1), WEIGHT_WIDTH+2);
						end loop;
						w4_tmp := ext(w2(3), WEIGHT_WIDTH+2) + ext(w(0), WEIGHT_WIDTH+2);
						sumW <= ext(w4_tmp, WEIGHT_WIDTH+4) + ext(w4(1), WEIGHT_WIDTH+4);
					end if;
					if (PIXEL_CNT = 5) then
						for i in 1 to (PIXEL_CNT-1)/2 loop
							w2(i) := ext(w(2*i), WEIGHT_WIDTH+1) + ext(w(2*i-1), WEIGHT_WIDTH+1);
						end loop;
						w4_tmp := ext(w2(1), WEIGHT_WIDTH+2) + ext(w2(2), WEIGHT_WIDTH+2);
						sumW <= ext(w4_tmp, WEIGHT_WIDTH+4) + ext(w(0), WEIGHT_WIDTH+4);		-- w(0) always (others=> '1')
					end if;
					if (PIXEL_CNT = 3) then
						w2(1) := ext(w(2), WEIGHT_WIDTH+1) + ext(w(1), WEIGHT_WIDTH+1);
						sumW <= ext(w2(1), WEIGHT_WIDTH+4) + ext(w(0), WEIGHT_WIDTH+4);
					end if;
				end if;
			end if;
		end if;
	end process;

	-- stage 6,7,8,9
	L_sumW: delay_vector_en
		generic map
		(
			delay => 4,
			msb => WEIGHT_WIDTH+3
		)
		port map
		(
			clk => clk,
			d_in => sumW,
			d_out => sumW_delayed,
			en => run_en,
			reset => reset
		);

	-- stage 7,8,9
	process(clk)
	type   		weightedPixel2 	is array ((PIXEL_CNT-1) downto 1) of std_logic_vector (DATA_IN_WIDTH+WEIGHT_WIDTH-0 downto 0);
	variable	Dw2:	weightedPixel2;
	begin
		if clk'event and clk = '1' then
			-- if reset = '1' then
			-- 	Dw4 <= (others => (others => '0'));
			-- 	D0w_d1 <= (others => '0');
			-- 	Dw8 <= (others => (others => '0'));
			-- 	D0w_d2 <= (others => '0');
			-- 	sumDxW <= (others => '0');
			-- else
				for i in 1 to (PIXEL_CNT-1)/2 loop
					Dw2(i) := ext(D_weighted(2*i), DATA_IN_WIDTH+WEIGHT_WIDTH+1) + ext(D_weighted(2*i-1), DATA_IN_WIDTH+WEIGHT_WIDTH+1);
				end loop;
				if (run_en = '1') then
					if (PIXEL_CNT = 9) then
						for i in 1 to (PIXEL_CNT-1)/4 loop
							Dw4(i) <= ext(Dw2(2*i), DATA_IN_WIDTH+WEIGHT_WIDTH+2) + ext(Dw2(2*i-1), DATA_IN_WIDTH+WEIGHT_WIDTH+2);
						end loop;
						D0w_d1 <= D_weighted(0);
						for i in 1 to (PIXEL_CNT-1)/8 loop
							Dw8(i) <= ext(Dw4(2*i), DATA_IN_WIDTH+WEIGHT_WIDTH+3) + ext(Dw4(2*i-1), DATA_IN_WIDTH+WEIGHT_WIDTH+3);
						end loop;
						D0w_d2 <= D0w_d1;
						sumDxW <= ext(D0w_d2, DATA_IN_WIDTH+WEIGHT_WIDTH+4) + ext(Dw8(1), DATA_IN_WIDTH+WEIGHT_WIDTH+4);
					end if;
					if (PIXEL_CNT = 7) then
						for i in 1 to (PIXEL_CNT-1)/4 loop
							Dw4(i) <= ext(Dw2(2*i), DATA_IN_WIDTH+WEIGHT_WIDTH+2) + ext(Dw2(2*i-1), DATA_IN_WIDTH+WEIGHT_WIDTH+2);
						end loop;
						Dw4_tmp <= ext(D_weighted(0), DATA_IN_WIDTH+WEIGHT_WIDTH+2) + ext(Dw2(3), DATA_IN_WIDTH+WEIGHT_WIDTH+2);
						sumDxW <= ext(Dw4_tmp, DATA_IN_WIDTH+WEIGHT_WIDTH+4) + ext(Dw4(1), DATA_IN_WIDTH+WEIGHT_WIDTH+4);
					end if;
					if (PIXEL_CNT = 5) then
						for i in 1 to (PIXEL_CNT-1)/4 loop
							Dw4(i) <= ext(Dw2(2*i), DATA_IN_WIDTH+WEIGHT_WIDTH+2) + ext(Dw2(2*i-1), DATA_IN_WIDTH+WEIGHT_WIDTH+2);
						end loop;
						D0w_d1 <= D_weighted(0);
						sumDxW <= ext(D0w_d1, DATA_IN_WIDTH+WEIGHT_WIDTH+4) + ext(Dw4(1), DATA_IN_WIDTH+WEIGHT_WIDTH+4);
					end if;
					if (PIXEL_CNT = 3) then
						Dw4_tmp <= ext(D_weighted(0), DATA_IN_WIDTH+WEIGHT_WIDTH+2) + ext(Dw2(1), DATA_IN_WIDTH+WEIGHT_WIDTH+2);
						sumDxW <= ext(Dw4_tmp, DATA_IN_WIDTH+WEIGHT_WIDTH+4);
					end if;
				end if;
			-- end if;
		end if;
	end process;

	dividend	<= '0'&sumDxW;
	divisor		<= '0'&sumW_delayed;

	-- stage 10-30 (19+2 +9)
divD_10 : IF (DATA_IN_WIDTH = 10) GENERATE
    s_axis_dividend_tdata	<= ext(dividend, s_axis_dividend_tdata'length);
    s_axis_divisor_tdata	<= ext(divisor, s_axis_divisor_tdata'length);

	Div_D : uudiv19_9
	port map
	(
		aclk => clk,
		aclken => run_en,
		s_axis_divisor_tvalid => '1',
		s_axis_divisor_tdata => s_axis_divisor_tdata,
		s_axis_dividend_tvalid => '1',
		s_axis_dividend_tdata => s_axis_dividend_tdata,
		m_axis_dout_tvalid => open,
		m_axis_dout_tdata => m_axis_dout_tdata
	);

	DxWdivW		<= m_axis_dout_tdata(19+16-1 downto 16);
	reminder	<= m_axis_dout_tdata(8 downto 0);

	-- Div_D : uuDiv19_9
	-- 	port map
	-- 	(
	-- 		clk => clk,
	-- 		ce => run_en,
	-- 		sclr => reset,
	-- 		dividend => dividend,
	-- 		divisor => divisor,
	-- 		quotient => DxWdivW,
	-- 		fractional => reminder,
	-- 		rfd => open
	-- 	);
END GENERATE;

	-- stage 10-32 (21+2 +9)
divD_12 : IF (DATA_IN_WIDTH = 12) GENERATE
	-- Div_D : uuDiv21_9
	-- 	port map
	-- 	(
	-- 		clk => clk,
	-- 		ce => run_en,
	-- 		sclr => reset,
	-- 		dividend => dividend,
	-- 		divisor => divisor,
	-- 		quotient => DxWdivW,
	-- 		fractional => reminder,
	-- 		rfd => open
	-- 	);
END GENERATE;

	data_out <= data_out_tmp;

	dc <= '1' when (col < DC_NUM) else '0';

	process(clk)
		variable DxWdivWp1	: std_logic_vector(DATA_IN_WIDTH-1 downto 0);
	begin
		if clk'event and clk = '1' then
			if (reset = '1') then
				data_out_tmp	<= (others => '0');
				col				<= (others => '0');
				dc_d1			<= '0';
			else
				DxWdivWp1 := DxWdivW(DATA_IN_WIDTH-1 downto 0) + 1;

				if (run_en = '1') then
					if (col = imageWidth-1) then
						col <= (others => '0');
					else
						col <= col + 1;
					end if;

					if (reminder < '0'&divisor(WEIGHT_WIDTH+4 downto 1)) then
						data_out_tmp <= DxWdivW(DATA_IN_WIDTH-1 downto 0);
					else
						if (DxWdivWp1 = 0) then
							data_out_tmp <= (others => '1');
						else
							data_out_tmp <= DxWdivWp1;
						end if;
					end if;
					dc_d1 <= dc;
				end if;
			end if;
		end if;
	end process;

	process(clk)
	begin
		if clk'event and clk = '1' then
			if (reset = '1') then
				data_ready_cnt <= (others => '0');
				data_ready  <= '0';
			else
				if (run_en = '1') then
					if (data_ready_cnt = tnk_delay-1) then
						data_ready <= '1';
					else
						data_ready_cnt <= data_ready_cnt + 1;
						data_ready <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;

	cs_en : if CHIPSCOPE_EN = 1 generate

		-- icon_2_inst : icon_2
		  -- port map (
			-- CONTROL0 => CONTROL0,
			-- CONTROL1 => CONTROL1);

		-- ila_128_inst : ila_128
		  -- port map (
			-- CONTROL => CONTROL0,
			-- CLK => clk,
			-- TRIG0 => TRIG0);

		-- TRIG0((10*1-1) downto 10*0) <= data_in(0);
		-- TRIG0((10*2-1) downto 10*1) <= data_in(1);
		-- TRIG0((10*3-1) downto 10*2) <= data_in(2);
		-- TRIG0((10*4-1) downto 10*3) <= data_in(3);
		-- TRIG0((10*5-1) downto 10*4) <= data_in(4);
		-- TRIG0((10*6-1) downto 10*5) <= data_in(5);
		-- TRIG0((10*7-1) downto 10*6) <= data_in(6);
		-- TRIG0((10*8-1) downto 10*7) <= data_in(7);
		-- TRIG0((10*9-1) downto 10*8) <= data_in(8);

		-- TRIG0(90)					<= tr_ready;
		-- TRIG0(91)					<= re_ready;
		-- TRIG0(92)					<= average_DC;
		-- TRIG0(93)					<= dc;
		-- TRIG0((105) downto 94) 		<= col;
		-- TRIG0((127) downto 106) 	<= (others => '0');

		-- vio_380_INST : vio_380
		  -- port map (
			-- CONTROL => CONTROL1,
			-- CLK => clk,
			-- ASYNC_IN => ASYNC_IN,
			-- SYNC_IN => SYNC_IN);

			-- SYNC_IN(242 downto 0) 		<= tnk_frame_addr_p(27 * 9 - 1 downto 0);
			-- SYNC_IN(255 downto 243)		<= (others => '0');

			-- ASYNC_IN(10 * 9 - 1 downto 0)	<= tnk_initial_skip_p(10 * 9 - 1 downto 0);
			-- ASYNC_IN(116 downto 90)			<= tnk_dump_step_p(3 * 9 - 1 downto 0);
			-- ASYNC_IN(255 downto 117)		<= (others => '0');


	end generate cs_en;

end Behavioral;
