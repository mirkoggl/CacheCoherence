library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.logpack.all;
 
ENTITY tb IS
END tb;
 
ARCHITECTURE behavior OF tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
   component cache_controller
   	generic(DIRECTORY_ID     : natural := 0;
   		    DIRECTORIES_N    : natural := 16;
   		    DATA_WIDTH       : natural := 32;
   		    MEM_ADDR_WIDTH   : natural := 8;
   		    ROUTER_MEX_WIDTH : natural := 16;
   		    FIFO_REQ_WIDTH   : natural := 8);
   	Port(
		clk            : in  std_logic;
		reset          : in  std_logic;
		enable         : in  std_logic;

		-- Core interface
		CoreValidIn    : in  std_logic; -- Core valid signal, high if there is a valid request from the core
		CoreMexIn      : in  std_logic_vector(MEM_ADDR_WIDTH downto 0); -- Request from the core (load and store) 
		CoreDataIn     : in  std_logic_vector(DATA_WIDTH - 1 downto 0); -- Data from the core (in case of store)
		CoreValidOut   : out std_logic; -- Core valid out, if high there is a valid response for the core 
		CoreMexOut     : out std_logic_vector(MEM_ADDR_WIDTH downto 0); -- Response for the core
		CoreDataOut    : out std_logic_vector(DATA_WIDTH - 1 downto 0); -- Data from the core (in case of load)

		-- Router Interface
		RouterValidIn  : in  std_logic;
		RouterDataIn   : in  std_logic_vector(ROUTER_MEX_WIDTH - 1 downto 0);
		RouterValidOut : out std_logic;
		RouterDataOut  : out std_logic_vector(ROUTER_MEX_WIDTH - 1 downto 0);

		-- Memory interface
		CacheDataIn    : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		CacheReadAddr  : out std_logic_vector(MEM_ADDR_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
		CacheWriteEn   : out std_logic;
		CacheWriteAddr : out std_logic_vector(MEM_ADDR_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
		CacheDataOut   : out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
   end component cache_controller;
   
   component llc_memory
   	generic(DATA_WIDTH : natural := 8;
   		    ADDR_WIDTH : natural := 6);
   	port(clk   : in  std_logic;
   		 raddr : in  natural range 0 to 2 ** ADDR_WIDTH - 1;
   		 waddr : in  natural range 0 to 2 ** ADDR_WIDTH - 1;
   		 data  : in  std_logic_vector((DATA_WIDTH - 1) downto 0);
   		 we    : in  std_logic := '1';
   		 q     : out std_logic_vector(DATA_WIDTH - 1 downto 0));
   end component llc_memory;
	
	
	constant DIRECTORY_ID     : natural := 0;
   	constant DIRECTORIES_N    : natural := 4;
   	constant DATA_WIDTH       : natural := 8;
   	constant MEM_ADDR_WIDTH   : natural := 8;
   	constant ROUTER_MEX_WIDTH : natural := 16;
   	constant FIFO_REQ_WIDTH   : natural := 8;
   	
   --Inputs
   signal clk, reset, enable : std_logic := '0';
   
	signal CoreValidIn    :  std_logic := '0';
   	signal CoreMexIn      :  std_logic_vector(MEM_ADDR_WIDTH downto 0) := (others => '0');
   	signal CoreDataIn     :  std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
   	signal CoreValidOut   :  std_logic := '0';
   	signal CoreMexOut     :  std_logic_vector(MEM_ADDR_WIDTH downto 0) := (others => '0');
   	signal CoreDataOut    :  std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
   	signal RouterValidIn  :  std_logic := '0';
   	signal RouterDataIn   :  std_logic_vector(ROUTER_MEX_WIDTH - 1 downto 0) := (others => '0');
   	signal RouterValidOut :  std_logic := '0';
   	signal RouterDataOut  :  std_logic_vector(ROUTER_MEX_WIDTH - 1 downto 0) := (others => '0');
   	signal CacheDataIn    :  std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
   	signal CacheReadAddr  :  std_logic_vector(MEM_ADDR_WIDTH- f_log2(DIRECTORIES_N) - 1 downto 0) := (others => '0');
   	signal CacheWriteEn   :  std_logic := '0';
   	signal CacheWriteAddr :  std_logic_vector(MEM_ADDR_WIDTH- f_log2(DIRECTORIES_N) - 1 downto 0) := (others => '0');
   	signal CacheDataOut   :  std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');	
	
	
	-- Clock period definitions
   constant clk_period : time := 10 ns;
  
   signal ReadAddr, ReadAddr_temp : natural range 0 to 2 ** (MEM_ADDR_WIDTH- f_log2(DIRECTORIES_N)) - 1;
   signal WriteAddr, WriteAddr_temp : natural range 0 to 2 ** (MEM_ADDR_WIDTH- f_log2(DIRECTORIES_N)) - 1;
   signal data, data_temp : std_logic_vector((DATA_WIDTH - 1) downto 0) := (others => '0');
   signal we, we_temp : std_logic := '0';
   
BEGIN
 
 	
	-- Instantiate the Unit Under Test (UUT)
   cc_uut : cache_controller
   	generic map(
   		DIRECTORY_ID     => DIRECTORY_ID,
   		DIRECTORIES_N      => DIRECTORIES_N,
   		DATA_WIDTH       => DATA_WIDTH,
   		MEM_ADDR_WIDTH   => MEM_ADDR_WIDTH,
   		ROUTER_MEX_WIDTH => ROUTER_MEX_WIDTH,
   		FIFO_REQ_WIDTH   => FIFO_REQ_WIDTH
   	)
   	port map(
   		clk            => clk,
   		reset          => reset,
   		enable         => enable,
   		CoreValidIn    => CoreValidIn,
   		CoreMexIn      => CoreMexIn,
   		CoreDataIn     => CoreDataIn,
   		CoreValidOut   => CoreValidOut,
   		CoreMexOut     => CoreMexOut,
   		CoreDataOut    => CoreDataOut,
   		RouterValidIn  => RouterValidIn,
   		RouterDataIn   => RouterDataIn,
   		RouterValidOut => RouterValidOut,
   		RouterDataOut  => RouterDataOut,
   		CacheDataIn    => CacheDataIn,
   		CacheReadAddr  => CacheReadAddr,
   		CacheWriteEn   => CacheWriteEn,
   		CacheWriteAddr => CacheWriteAddr,
   		CacheDataOut   => CacheDataOut
   	);
   	
   	mem_uut : llc_memory
   		generic map(
   			DATA_WIDTH => DATA_WIDTH,
   			ADDR_WIDTH => MEM_ADDR_WIDTH- f_log2(DIRECTORIES_N)
   		)
   		port map(
   			clk   => clk,
   			raddr => ReadAddr,
   			waddr => WriteAddr,
   			data  => data,
   			we    => we,
   			q     => CacheDataIn
   		);
 
   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 
   ReadAddr <= CONV_INTEGER(CacheReadAddr) when enable = '1' else ReadAddr_temp;
   WriteAddr<= CONV_INTEGER(CacheWriteAddr) when enable = '1' else WriteAddr_temp;
   we <= CacheWriteEn when enable = '1' else we_temp;
   data <= CacheDataOut when enable = '1' else data_temp; 
 
   -- Stimulus process
   stim_proc: process
   begin		
   	-- hold reset state for 100 ns.
   	  reset <= '1';
   	 
    	  
      wait for 100 ns;	
	  reset <= '0';
	  we_temp <= '1';
	  WriteAddr_temp <= 0;
	  data_temp <= x"01";
	  
	  wait for clk_period;
	  WriteAddr_temp <= 1;
	  data_temp <= x"02";
	  
	  wait for clk_period;
	  WriteAddr_temp <= 2;
	  data_temp <= x"03";
	  
	  wait for clk_period;
	  WriteAddr_temp <= 3;
	  data_temp <= x"04";
	  
	  wait for clk_period;
	  WriteAddr_temp <= 4;
	  data_temp <= x"05";
	  
	  wait for clk_period;
	  WriteAddr_temp <= 5;
	  data_temp <= x"06";
	  
	  wait for clk_period;
	  WriteAddr_temp <= 6;
	  data_temp <= x"07";
	  
	  wait for clk_period;
	  WriteAddr_temp <= 7;
	  data_temp <= x"08";
	  
	  wait for clk_period;
	  we_temp <= '0';
	  
	  
	  wait for clk_period;
	  enable <= '1';
	  
	  wait for clk_period * 10;
	  CoreValidIn <= '1';
	  CoreMexIn <= "100000001";
	  CoreDataIn <= x"10";
	  
	  wait for clk_period;
	  CoreValidIn <= '0';
	  
	  wait for clk_period * 10;
	  CoreValidIn <= '1';
	  CoreMexIn <= "100000100";
	  CoreDataIn <= x"11";
	   
	  wait for clk_period;
	  CoreValidIn <= '0';
      
      wait for clk_period * 10;
	  CoreValidIn <= '1';
	  CoreMexIn <= "100000010";
	  CoreDataIn <= x"12";
	  
	  wait for clk_period;
	  CoreValidIn <= '0';	  
	  
	  wait for clk_period * 10;
	  CoreValidIn <= '1';
	  CoreMexIn <= "000000011";
	  
	  wait for clk_period;
	  CoreValidIn <= '0';
	  
	  wait for clk_period * 10;
	  CoreValidIn <= '1';
	  CoreMexIn <= "000000101";
	  
	  wait for clk_period;
	  CoreValidIn <= '0';
	  
      wait;
   end process;

END;