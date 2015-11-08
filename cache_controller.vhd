library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.logpack.all;

entity cache_controller is
	Generic(
		DIRECTORY_ID   : natural := 0;  -- This Directory identifier
		DIRECTORIES_N  : natural := 4;  -- Directories number
		DATA_WIDTH     : natural := 32; -- Data width
		MEM_ADDR_WIDTH : natural := 8;  -- Memory address width
		-- Message to/from core width -> memory address width + 1 bit for discern if it is a load or a store request 
		--ROUTER_MEX_WIDTH : natural := 12;

		FIFO_REQ_WIDTH : natural := 8   -- Internal FIFO length. If the controller is busy, concurrent request are stored in the Request FIFO
	);
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
		RouterDataIn   : in  std_logic_vector(f_log2(DIRECTORIES_N) + MEM_ADDR_WIDTH + 2 - 1 downto 0); -- 2 are the possible message type (Fwd-Get-M and Fwd-Get-S)
		RouterValidOut : out std_logic;
		RouterDataOut  : out std_logic_vector(f_log2(DIRECTORIES_N) + MEM_ADDR_WIDTH + 2 - 1 downto 0);

		-- Memory interface
		CacheDataIn    : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		CacheReadAddr  : out std_logic_vector(MEM_ADDR_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
		CacheWriteEn   : out std_logic;
		CacheWriteAddr : out std_logic_vector(MEM_ADDR_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
		CacheDataOut   : out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end entity cache_controller;

architecture RTL of cache_controller is
	constant STATE_BIT_WIDTH   : natural := 2;
	constant OWNER_WIDTH       : natural := f_log2(DIRECTORIES_N);
	constant SHARER_LIST_WIDTH : natural := DIRECTORIES_N;
	constant DIRECTORY_WIDTH   : natural := STATE_BIT_WIDTH + OWNER_WIDTH + SHARER_LIST_WIDTH;

	-- Core/Controller message constants
	constant LOAD_REQUEST  : std_logic                                 := '0';
	constant STORE_REQUEST : std_logic                                 := '1';
	constant ACK_CORE      : std_logic_vector(MEM_ADDR_WIDTH downto 0) := (others => '1');

	-- Router/Controller message constants
	constant FWD_GET_M : std_logic_vector(1 downto 0) := "00";
	constant FWD_GET_S : std_logic_vector(1 downto 0) := "01";

	-- MESI State value constant 
	constant INVALID_STATE   : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "00";
	constant MODIFIED_STATE  : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "01";
	constant SHARED_STATE    : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "10";
	constant EXCLUSIVE_STATE : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "11";

	--States: 
	--       00 -> Invalid
	--       01 -> Shared
	--       10 -> Modified
	--       11 -> Exclusice
	type directory_entry is record
		state  : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0);
		owner  : std_logic_vector(OWNER_WIDTH - 1 downto 0);
		sharer : std_logic_vector(SHARER_LIST_WIDTH - 1 downto 0);
	end record;
	type directory_t is array (2 ** MEM_ADDR_WIDTH - 1 downto 0) of directory_entry;
	constant DIRECTORY_ENTRY_INIT : directory_entry := (
		state  => (others => '0'),
		owner  => (others => '0'),
		sharer => (others => '0')
	);
	signal directory : directory_t := (others => DIRECTORY_ENTRY_INIT); -- All directory entry start in Invalid state.

	-- Core request FIFO. If a request arrives when another is under processing, the request is stored and processed when the first is completed
	type request_fifo_t is array (FIFO_REQ_WIDTH - 1 downto 0) of std_logic_vector(MEM_ADDR_WIDTH downto 0);
	signal core_request_fifo     : request_fifo_t                                        := (others => (others => '0'));
	signal head_pt, tail_pt      : std_logic_vector(f_log2(FIFO_REQ_WIDTH) - 1 downto 0) := (others => '0');
	signal fifo_full, fifo_empty : std_logic                                             := '0';

	-- FSM and temporany signals 
	type state_type is (idle, core_req, others_req, load_mem, getS, getM, wait_remote_getS, wait_c);
	signal current_s, next_s                           : state_type                                                                := idle;
	signal core_mex_temp                               : std_logic_vector(MEM_ADDR_WIDTH downto 0)                                 := (others => '0');
	signal core_data_temp                              : std_logic_vector(DATA_WIDTH - 1 downto 0)                                 := (others => '0');
	signal router_data_temp                            : std_logic_vector(f_log2(DIRECTORIES_N) + MEM_ADDR_WIDTH + 2 - 1 downto 0) := (others => '0');
	signal router_valid_out                            : std_logic                                                                 := '0';
	signal router_data_out                             : std_logic_vector(f_log2(DIRECTORIES_N) + MEM_ADDR_WIDTH + 2 - 1 downto 0) := (others => '0');
	signal core_valid_out_temp, cache_write_en_temp    : std_logic                                                                 := '0';
	signal core_mex_out_temp                           : std_logic_vector(MEM_ADDR_WIDTH downto 0)                                 := (others => '0');
	signal cache_read_addr_temp, cache_write_addr_temp : std_logic_vector(MEM_ADDR_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0)     := (others => '0');
	signal core_data_out_temp, cache_data_out_temp     : std_logic_vector(DATA_WIDTH - 1 downto 0)                                 := (others => '0');
	signal home_node : std_logic_vector(f_log2(DIRECTORIES_N)-1 downto 0) := (others => '0');

	signal requestor_id : natural := 0;

begin
	CoreValidOut <= core_valid_out_temp;
	CoreMexOut   <= core_mex_out_temp;
	CoreDataOut  <= core_data_out_temp;

	CacheWriteEn   <= cache_write_en_temp;
	CacheWriteAddr <= cache_write_addr_temp;
	CacheReadAddr  <= cache_read_addr_temp;
	CacheDataOut   <= cache_data_out_temp;

	RouterValidOut <= router_valid_out;

	fifo_full <= '1' when head_pt = (tail_pt + '1')
		else '0';

	fifo_empty <= '1' when head_pt = tail_pt
		else '0';

	CU_process : process(clk, reset, enable)
	begin
		if reset = '1' then
			next_s            <= idle;
			current_s         <= idle;
			directory         <= (others => DIRECTORY_ENTRY_INIT);
			core_request_fifo <= (others => (others => '0'));
			head_pt           <= (others => '0');
			tail_pt           <= (others => '0');

		elsif rising_edge(clk) and enable = '1' then
			core_valid_out_temp <= '0';
			core_mex_out_temp   <= (others => '0');
			cache_write_en_temp <= '0';
			router_valid_out    <= '0';

			case current_s is
				when idle =>
					if CoreValidIn = '1' then
						current_s      <= core_req;
						core_mex_temp  <= CoreMexIn;
						core_data_temp <= CoreDataIn;
					elsif RouterValidIn = '1' then
						current_s        <= others_req;
						router_data_temp <= RouterDataIn;
					else
						current_s <= idle;
					end if;

				when core_req =>
					if core_mex_temp(MEM_ADDR_WIDTH) = LOAD_REQUEST then -- LOAD REQUEST

						if directory(CONV_INTEGER(core_mex_temp(MEM_ADDR_WIDTH - 1 downto 0))).state = SHARED_STATE then -- If the block is already in Shared state and it can be load
							current_s            <= wait_c; -- Wait 1 clock cycle for memory response
							next_s               <= load_mem;
							cache_read_addr_temp <= core_mex_temp(MEM_ADDR_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
						else            -- else we need to get the Shared state for this block
							current_s    <= getS;
							requestor_id <= DIRECTORY_ID;
						end if;

					else                -- STORE REQUEST
						if directory(CONV_INTEGER(core_mex_temp(MEM_ADDR_WIDTH - 1 downto 0))).state = MODIFIED_STATE then -- If is already in Modified state
							-- Ack to Core
							core_valid_out_temp   <= '1';
							core_mex_out_temp     <= ACK_CORE;
							-- Write in Cache
							cache_write_en_temp   <= '1';
							cache_data_out_temp   <= core_data_temp;
							cache_write_addr_temp <= core_mex_temp(MEM_ADDR_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
							current_s             <= idle;
						else            -- else we need to get the Modified state for this block
							current_s    <= getM;
							requestor_id <= DIRECTORY_ID;
						end if;

					end if;

				when load_mem =>        -- Ack to Core and upload the data				
					core_valid_out_temp <= '1';
					core_mex_out_temp   <= ACK_CORE;
					core_data_out_temp  <= CacheDataIn;
					current_s           <= idle;

				when others_req =>
				when getS       =>
					-- We need to find the  home node for this block
					if core_mex_temp(MEM_ADDR_WIDTH - 1 downto MEM_ADDR_WIDTH - 1 - f_log2(DIRECTORIES_N)) = CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) then -- If this condition is true the current node is the home 
						if directory(CONV_INTEGER(core_mex_temp(MEM_ADDR_WIDTH - 1 downto 0))).state = MODIFIED_STATE then -- If the block is modified we need to recall it
						-- Fwd-GetS to the owner and wait for the update data
						else            -- If is invalid the directory can reponse with data to the requestor
							directory(CONV_INTEGER(core_mex_temp(MEM_ADDR_WIDTH - 1 downto 0))).state                <= SHARED_STATE;
							directory(CONV_INTEGER(core_mex_temp(MEM_ADDR_WIDTH - 1 downto 0))).sharer(requestor_id) <= '1';
							current_s                                                                                <= wait_c; -- Wait 1 clock cycle for memory response
							next_s                                                                                   <= load_mem;
							cache_read_addr_temp                                                                     <= core_mex_temp(MEM_ADDR_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
						end if;
					else
						-- Send mex to the home node
						router_valid_out <= '1';
						-- Dest + Source + Message type + Block Address Request
						router_data_out  <= core_mex_temp(MEM_ADDR_WIDTH - 1 downto MEM_ADDR_WIDTH - 1 - f_log2(DIRECTORIES_N)) & CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) & FWD_GET_S & core_mex_temp(MEM_ADDR_WIDTH - 1 - f_log2(DIRECTORIES_N) - 1 downto 0);
						home_node <= core_mex_temp(MEM_ADDR_WIDTH - 1 downto MEM_ADDR_WIDTH - 1 - f_log2(DIRECTORIES_N));
						current_s        <= wait_remote_getS;
					end if;

				when wait_remote_getS =>
					if RouterValidIn = '1' and RouterDataIn(MEM_ADDR_WIDTH + 2 - 1 downto MEM_ADDR_WIDTH + 2 - f_log2(DIRECTORIES_N)) = home_node then
						-- The home node responded. The controller must save the data in cache and set it has shared
						current_s <= idle;
					else
						current_s <= wait_remote_getS;						
					end if;				
					
				when getM             =>
					-- We need to find the  home node for this block
					if core_mex_temp(MEM_ADDR_WIDTH - 1 downto MEM_ADDR_WIDTH - 1 - f_log2(DIRECTORIES_N)) = CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) then -- If this condition is true the current node is the home 
						if directory(CONV_INTEGER(core_mex_temp(MEM_ADDR_WIDTH - 1 downto 0))).state = INVALID_STATE then
							-- Update directory entry
							directory(CONV_INTEGER(core_mex_temp(MEM_ADDR_WIDTH - 1 downto 0))).state  <= MODIFIED_STATE; -- Set the block as modified
							directory(CONV_INTEGER(core_mex_temp(MEM_ADDR_WIDTH - 1 downto 0))).sharer <= (others => '0'); -- Sharer should be already 0
							directory(CONV_INTEGER(core_mex_temp(MEM_ADDR_WIDTH - 1 downto 0))).owner  <= CONV_STD_LOGIC_VECTOR(requestor_id, OWNER_WIDTH); -- Save the Owner
							-- Store the data in memory
							cache_write_en_temp                                                        <= '1';
							cache_data_out_temp                                                        <= core_data_temp;
							cache_write_addr_temp                                                      <= core_mex_temp(MEM_ADDR_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
							current_s                                                                  <= idle;
						elsif directory(CONV_INTEGER(core_mex_temp(MEM_ADDR_WIDTH - 1 downto 0))).state = SHARED_STATE then -- If the block is shared all sharers must be awared
						-- AckCount and send Invalidation to all sharers
						-- Send can be with multicast
						else            -- The block is already modified
						-- Fwd-GetM to the owner
						end if;
					end if;

				when wait_c =>
					current_s <= next_s;

			end case;

		end if;
	end process;

end architecture RTL;
