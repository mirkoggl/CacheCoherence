library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.logpack.all;

ENTITY tb_cache IS
END tb_cache;

ARCHITECTURE behavior OF tb_cache IS

	-- Component Declaration for the Unit Under Test (UUT)
	component cache_memory
		generic(DATA_WIDTH  : natural := 32;
			    BLOCK_WIDTH : natural := 16;
			    CACHE_WIDTH : natural := 4);
		port(clk   : in  std_logic;
			 reset : in  std_logic;
			 addr  : in  std_logic_vector(BLOCK_WIDTH - 1 downto 0);
			 op    : in  std_logic_vector(1 downto 0);
			 data  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
			 hit   : out std_logic;
			 q     : out std_logic_vector(DATA_WIDTH - 1 downto 0));
	end component cache_memory;

	constant DATA_WIDTH  : natural := 8;
	constant BLOCK_WIDTH : natural := 16;
	constant CACHE_WIDTH : natural := 4;

	--Inputs
	signal clk, reset, enable : std_logic                                  := '0';
	signal addr               : std_logic_vector(BLOCK_WIDTH - 1 downto 0) := (others => '0');
	signal op                 : std_logic_vector(1 downto 0);
	signal data               : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');
	signal hit                : std_logic;
	signal q                  : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');

	-- Clock period definitions
	constant clk_period : time := 10 ns;

BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut : cache_memory
		generic map(
			DATA_WIDTH  => DATA_WIDTH,
			BLOCK_WIDTH => BLOCK_WIDTH,
			CACHE_WIDTH => CACHE_WIDTH
		)
		port map(
			clk   => clk,
			reset => reset,
			addr  => addr,
			op    => op,
			data  => data,
			hit   => hit,
			q     => q
		);

	-- Clock process definitions
	clk_process : process
	begin
		clk <= '0';
		wait for clk_period / 2;
		clk <= '1';
		wait for clk_period / 2;
	end process;

	-- Stimulus process
	stim_proc : process
	begin
		-- hold reset state for 100 ns.
		reset <= '1';

		wait for 100 ns;
		reset <= '0';
		op   <= "01";
		addr <= x"002A";
		data <= x"01";
		
		wait for clk_period;
		addr <= x"0051";
		data <= x"02";
		
		wait for clk_period;
		addr <= x"0032";
		data <= x"03";
		
		wait for clk_period; 
		addr <= x"0117";
		data <= x"04";
		
		wait for clk_period;
		addr <= x"0998";
		data <= x"05";
		
		wait for clk_period;
		op <= "11";
		
		wait for clk_period * 10;
		op <= "00";
		addr <= x"002A";
		
		wait for clk_period;
		addr <= x"000A";
		
		wait for clk_period;
		addr <= x"0051";
		
		wait for clk_period;
		op <= "11";
		
		
		wait;
		
	end process;

	END;