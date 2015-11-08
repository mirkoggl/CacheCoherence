library ieee;
use ieee.std_logic_1164.all;

entity llc_memory is
	Generic(
		DATA_WIDTH : natural := 8;
		ADDR_WIDTH : natural := 6
	);
	Port(
		clk		: in std_logic;
		raddr	: in natural range 0 to 2**ADDR_WIDTH-1;		-- Read address
		waddr	: in natural range 0 to 2**ADDR_WIDTH-1;		-- Write address	
		data	: in std_logic_vector((DATA_WIDTH-1) downto 0); -- Data input
		we		: in std_logic := '1';							-- Write enable
		q		: out std_logic_vector(DATA_WIDTH-1 downto 0)	-- Data output
	);
end llc_memory;

architecture rtl of llc_memory is

	-- Build a 2-D array type for the RAM
	subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
	type memory_t is array(2**ADDR_WIDTH-1 downto 0) of word_t;

	-- Declare the RAM signal.	
	signal ram : memory_t;

begin

	process(clk)
	begin
	if(rising_edge(clk)) then 
		if(we = '1') then
			ram(waddr) <= data;
		end if;
 
		-- On a read during a write to the same address, the read will
		-- return the OLD data at the address
		q <= ram(raddr);
	end if;
	end process;

end rtl;