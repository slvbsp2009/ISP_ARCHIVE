library ieee, work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GHOST_remover is
		generic
		(
			DATA_IN_WIDTH		: integer	:= 10;
			PIXEL_CNT			: integer	:= 9;		-- 9,7,5 or 3

			NORM				: natural	:= 10
		);
		port
		(
			clk:			in std_logic;
			reset:			in std_logic;

			sdata:			in std_logic_vector(DATA_IN_WIDTH * PIXEL_CNT - 1 downto 0);
			sdata_valid:	in std_logic;
			sdata_ready:	out std_logic;

			mdata:			out std_logic_vector(DATA_IN_WIDTH * PIXEL_CNT - 1 downto 0);
			mdata_valid:	out std_logic;
			mdata_ready:	in std_logic;

			coef:			in std_logic_vector(NORM-1 downto 0)
		);
end GHOST_remover;

architecture Behavioral of GHOST_remover is
	constant PIPE_DELAY			: natural	:= 3;

    signal arr_data_valid       : std_logic_vector(PIPE_DELAY-1 downto 0);
	signal run_en				: std_logic;
	signal mdata_valid_o		: std_logic;

    signal M0       : unsigned(NORM downto 0);

	type data_in_type	is array(PIXEL_CNT-1 downto 0) of std_logic_vector(DATA_IN_WIDTH-1 downto 0);
	signal data_in			: data_in_type;

	type data_type_0	is array(PIXEL_CNT-1 downto 1) of std_logic_vector(DATA_IN_WIDTH-1 downto 0);
	signal data_prev		: data_type_0	:= (others => (others => '0'));

	type data_type_m	is array(PIXEL_CNT-1 downto 1) of unsigned(DATA_IN_WIDTH+NORM-0 downto 0);
	signal data_prev_m, data_cur_m			: data_type_m	:= (others => (others => '0'));
	signal data_prev_m_c1, data_cur_m_c1	: data_type_m	:= (others => (others => '0'));

	type data_type_1	is array(PIXEL_CNT-1 downto 1) of unsigned(DATA_IN_WIDTH downto 0);
	signal data_fixed_tmp	: data_type_1	:= (others => (others => '0'));

	signal data_fixed		: data_type_0	:= (others => (others => '0'));
	signal data_fixed_bus	: std_logic_vector(DATA_IN_WIDTH*(PIXEL_CNT-1) - 1 downto 0);

	signal data0_c1, data0_c2	: std_logic_vector(DATA_IN_WIDTH - 1 downto 0);


begin

	assert (PIXEL_CNT > 1) report "PIXEL_CNT has to be > 1" severity failure;

    sdata_ready     <= (mdata_ready or not(mdata_valid_o)) and not(reset);
    mdata_valid     <= mdata_valid_o;
    mdata_valid_o	<= arr_data_valid(arr_data_valid'left);
	run_en			<= mData_ready or not(mdata_valid_o);
	mdata			<= data_fixed_bus&data0_c2;

	data_in_loop:
	for i in 0 to PIXEL_CNT-1 generate
		data_in(i) <= sdata((i+1)*DATA_IN_WIDTH-1 downto i*DATA_IN_WIDTH);
	end generate;


	pr_loop:
	for i in 1 to PIXEL_CNT-1 generate
		data_prev(i)		<= data_in(i-1);
		data_fixed_tmp(i)	<= unsigned(data_cur_m_c1(i)(data_cur_m_c1(1)'left downto NORM)) + unsigned(data_prev_m_c1(i)(data_prev_m_c1(1)'left downto NORM));
		data_fixed_bus(i*DATA_IN_WIDTH-1 downto (i-1)*DATA_IN_WIDTH)	<= data_fixed(i);

		process(clk)
		begin
			if clk'event and clk = '1' then
				if (run_en = '1') then
					-- step1
					data_cur_m(i) <= unsigned(data_in(i)) * M0;
					data_prev_m(i) <= unsigned(data_prev(i)) * unsigned('0'&coef);

					-- step2
					data_cur_m_c1(i) <= data_cur_m(i);
					data_prev_m_c1(i) <= data_prev_m(i);

					-- step3
					if (data_fixed_tmp(i)(DATA_IN_WIDTH) = '1') then
						data_fixed(i) <= (others => '1');
					else
						data_fixed(i) <= std_logic_vector(data_fixed_tmp(i)(DATA_IN_WIDTH-1 downto 0));
					end if;
				end if;
			end if;
		end process;
	end generate;

	process(clk)
	begin
		if clk'event and clk = '1' then
			M0	<= to_unsigned(2**NORM, NORM+1) - unsigned('0'&coef);
			if (reset = '1') then
				data0_c1	<= (others =>'0');
				data0_c2	<= (others =>'0');
			else
				if (run_en = '1') then
					data0_c1 <= data_in(0);
					data0_c2 <= data0_c1;
				end if;
			end if;
		end if;
	end process;

	process(clk)
	begin
		if clk'event and clk = '1' then
			if (reset = '1') then
				arr_data_valid	<= (others =>'0');
			else
				if (run_en = '1') then
					arr_data_valid <= arr_data_valid(arr_data_valid'left-1 downto 0) & sdata_valid;
				end if;
			end if;
		end if;
	end process;

end Behavioral;
