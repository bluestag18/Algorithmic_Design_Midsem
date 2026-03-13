library ieee;
use ieee.std_logic_1164.all;

entity QueueBase is
	generic(name : string; queue_depth: integer := 1; data_width: integer := 32;
		save_one_slot: boolean := false);
	port(clk: in std_logic;
	     reset: in std_logic;
	     data_in: in std_logic_vector(data_width-1 downto 0);
	     push_req: in std_logic;
	     push_ack: out std_logic;
	     data_out: out std_logic_vector(data_width-1 downto 0);
	     pop_ack : out std_logic;
	     pop_req: in std_logic);
end entity QueueBase;

architecture behave of QueueBase is

	type QueueArray is array(natural range <>) of std_logic_vector(data_width-1 downto 0);

	-- data memory for queue entries.
	signal queue_array : QueueArray(queue_depth-1 downto 0);

	-- read/write pointers (registers)
	signal read_pointer, write_pointer: integer range 0 to queue_depth - 1;

	-- queue size register (it is possible to implement the queue without using queue_size also).
	signal queue_size: integer range 0 to queue_depth;
begin  -- SimModel

	process(clk, reset, push_req, pop_req, read_pointer, write_pointer, queue_size, data_in, queue_array)
		variable next_queue_size_var: integer range 0 to queue_depth;
		variable next_read_pointer_var, next_write_pointer_var: integer range 0 to queue_depth-1;
		variable data_out_var : std_logic_vector(data_width-1 downto 0);
		variable push_ack_var, pop_ack_var : std_logic;
		variable do_push_var, do_pop_var : boolean;
	begin
		-------------------------------------------------------------------------
		-- Defaults
		-------------------------------------------------------------------------
		next_queue_size_var := queue_size;
		next_read_pointer_var := read_pointer;
		next_write_pointer_var := write_pointer;
		push_ack_var := '0';
		pop_ack_var  := '0';

		do_push_var := false;
		do_pop_var  := false;

		-------------------------------------------------------------------------
		-- accept push if queue has room
		-------------------------------------------------------------------------
		if(queue_size < queue_depth) then
			push_ack_var := '1';
		end if;

		-------------------------------------------------------------------------
		-- accept pop if queue has data
		-------------------------------------------------------------------------
		if(queue_size > 0) then
			pop_ack_var := '1';
		end if;

		-------------------------------------------------------------------------
		-- calculate next write pointer
		-------------------------------------------------------------------------
		if(push_req = '1') then
			if(push_ack_var = '1') then
				do_push_var := true;
				if(write_pointer = queue_depth-1) then
					next_write_pointer_var := 0;
				else 
					next_write_pointer_var := write_pointer + 1;
				end if;
			end if;
		end if;

		-------------------------------------------------------------------------
		-- calculate next read pointer
		-------------------------------------------------------------------------
		if(pop_req = '1') then
			if(pop_ack_var = '1') then
				do_pop_var := true;
				if(read_pointer = queue_depth-1) then
					next_read_pointer_var := 0;
				else 
					next_read_pointer_var := read_pointer + 1;
				end if;
			end if;
		end if;

		-------------------------------------------------------------------------
		-- calculate next queue size
		-------------------------------------------------------------------------
		if(do_push_var and (not do_pop_var)) then
			next_queue_size_var := queue_size + 1;
		elsif ((not do_push_var) and do_pop_var) then
			next_queue_size_var := queue_size - 1;
		end if;

		-------------------------------------------------------------------------
		-- combinational outputs..
		-------------------------------------------------------------------------
		push_ack <= push_ack_var;
		pop_ack  <= pop_ack_var;


		-------------------------------------------------------------------------
		-- top of queue.
		-------------------------------------------------------------------------
		data_out <= queue_array (read_pointer);

		-------------------------------------------------------------------------
		-- update registers
		-------------------------------------------------------------------------
		if (clk'event and  (clk = '1')) then
			if(reset = '1') then
				read_pointer <= 0;
				write_pointer <= 0;
				queue_size   <= 0;
			else
				read_pointer <= next_read_pointer_var;
				write_pointer <= next_write_pointer_var;
				queue_size <= next_queue_size_var;

				----------------------------------------------------------
				-- update memory entry.
				----------------------------------------------------------
				if (push_req = '1') and (push_ack_var = '1') then
					queue_array (write_pointer) <= data_in;
				end if;
			end if;
		end if;

	end process;

end behave;
