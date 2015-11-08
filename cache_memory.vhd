library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity cache_memory is
	Generic(
		DATA_WIDTH  : natural := 32;
		BLOCK_WIDTH : natural := 16;
		CACHE_WIDTH : natural := 4
	);
	Port(
		clk   : in  std_logic;
		reset : in  std_logic;

		addr  : in  std_logic_vector(BLOCK_WIDTH - 1 downto 0);  
		op    : in  std_logic_vector(1 downto 0);  
		data  : in  std_logic_vector(DATA_WIDTH - 1 downto 0); -- Data input
		hit   : out std_logic;
		q     : out std_logic_vector(DATA_WIDTH - 1 downto 0) -- Data output
	);
end entity cache_memory;

architecture RTL of cache_memory is
	subtype word_t is std_logic_vector(DATA_WIDTH - 1 downto 0);
	type cache_t is array (2 ** CACHE_WIDTH - 1 downto 0) of word_t;

	subtype tag_t is std_logic_vector(BLOCK_WIDTH - CACHE_WIDTH - 1 downto 0);
	type tag_table_t is array (2 ** CACHE_WIDTH - 1 downto 0) of tag_t;

	signal mem                        : cache_t                                    := (others => (others => '0'));
	signal tag_table                  : tag_table_t                                := (others => (others => '0'));
	signal valid_vector, dirty_vector : std_logic_vector(2 ** CACHE_WIDTH - 1 downto 0) := (others => '0');

	alias tag   : std_logic_vector(BLOCK_WIDTH - CACHE_WIDTH - 1 downto 0) is addr(BLOCK_WIDTH - 1 downto CACHE_WIDTH);
	alias index : std_logic_vector(CACHE_WIDTH - 1 downto 0) is addr(CACHE_WIDTH - 1 downto 0);

begin
	process(clk, reset)
	begin
		if reset = '1' then
			mem <= (others => (others => '0'));
			hit <= '0';
		elsif (rising_edge(clk)) then
			
			hit <= '0';
			
			if op = "01" then -- Write
				mem(CONV_INTEGER(index)) <= data;
				tag_table(CONV_INTEGER(index)) <= tag;
				valid_vector(CONV_INTEGER(index)) <= '1';
				--dirty_vector(CONV_INTEGER(index)) <= '1';
				hit <= '0';
			elsif op = "00" then -- Read
				if tag_table(CONV_INTEGER(index)) = tag and valid_vector(CONV_INTEGER(index)) = '1' then
					hit <= '1';
				end if;
			elsif op = "10" then -- Invalid Block
				valid_vector(CONV_INTEGER(index)) <= '0';
			end if;
			
			q <= mem(CONV_INTEGER(index));
		end if;
	end process;

end architecture RTL;
