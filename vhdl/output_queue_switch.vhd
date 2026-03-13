library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity switch_2x2 is
    generic (
        DATA_WIDTH  : integer := 32;
        QUEUE_DEPTH : integer := 1024
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        in_data_1_pipe_write_data : in  std_logic_vector(31 downto 0);
        in_data_1_pipe_write_req  : in  std_logic_vector(0 downto 0);
        in_data_1_pipe_write_ack  : out std_logic_vector(0 downto 0);

        in_data_2_pipe_write_data : in  std_logic_vector(31 downto 0);
        in_data_2_pipe_write_req  : in  std_logic_vector(0 downto 0);
        in_data_2_pipe_write_ack  : out std_logic_vector(0 downto 0);

        out_data_1_pipe_read_data : out std_logic_vector(31 downto 0);
        out_data_1_pipe_read_req  : in  std_logic_vector(0 downto 0);
        out_data_1_pipe_read_ack  : out std_logic_vector(0 downto 0);

        out_data_2_pipe_read_data : out std_logic_vector(31 downto 0);
        out_data_2_pipe_read_req  : in  std_logic_vector(0 downto 0);
        out_data_2_pipe_read_ack  : out std_logic_vector(0 downto 0)
    ); 
end entity;

architecture arch of switch_2x2 is

----------------------------------------------------------------
-- STATE TYPES
----------------------------------------------------------------

type state_1_type is (IDLE_1, SERVE_A_1, SERVE_B_1);
type state_2_type is (IDLE_2, SERVE_A_2, SERVE_B_2);
type state_3_type is (IDLE_3, GO_A_1, GO_B_1);
type state_4_type is (IDLE_4, GO_A_2, GO_B_2);

signal state_1, next_state_1 : state_1_type;
signal state_2, next_state_2 : state_2_type;
signal state_3, next_state_3 : state_3_type;
signal state_4, next_state_4 : state_4_type;

signal last_served_1, last_served_next_1 : std_logic;
signal last_served_2, last_served_next_2 : std_logic;
signal length_header_1 : unsigned(15 downto 0);
signal length_header_2 : unsigned(15 downto 0);

----------------------------------------------------------------
-- LENGTH COUNTERS
----------------------------------------------------------------

signal length_cnt_1 : unsigned(15 downto 0);
signal length_cnt_2 : unsigned(15 downto 0);

----------------------------------------------------------------
-- QUEUE SIGNALS
----------------------------------------------------------------

-- out1 <- in1
signal q_data_in_out1_in1  : std_logic_vector(DATA_WIDTH-1 downto 0);
signal q_push_req_out1_in1 : std_logic;
signal q_push_ack_out1_in1 : std_logic;
signal q_data_out_out1_in1 : std_logic_vector(DATA_WIDTH-1 downto 0);
signal q_pop_req_out1_in1  : std_logic;
signal q_pop_ack_out1_in1  : std_logic;

-- out1 <- in2
signal q_data_in_out1_in2  : std_logic_vector(DATA_WIDTH-1 downto 0);
signal q_push_req_out1_in2 : std_logic;
signal q_push_ack_out1_in2 : std_logic;
signal q_data_out_out1_in2 : std_logic_vector(DATA_WIDTH-1 downto 0);
signal q_pop_req_out1_in2  : std_logic;
signal q_pop_ack_out1_in2  : std_logic;

-- out2 <- in1
signal q_data_in_out2_in1  : std_logic_vector(DATA_WIDTH-1 downto 0);
signal q_push_req_out2_in1 : std_logic;
signal q_push_ack_out2_in1 : std_logic;
signal q_data_out_out2_in1 : std_logic_vector(DATA_WIDTH-1 downto 0);
signal q_pop_req_out2_in1  : std_logic;
signal q_pop_ack_out2_in1  : std_logic;

-- out2 <- in2
signal q_data_in_out2_in2  : std_logic_vector(DATA_WIDTH-1 downto 0);
signal q_push_req_out2_in2 : std_logic;
signal q_push_ack_out2_in2 : std_logic;
signal q_data_out_out2_in2 : std_logic_vector(DATA_WIDTH-1 downto 0);
signal q_pop_req_out2_in2  : std_logic;
signal q_pop_ack_out2_in2  : std_logic;

----------------------------------------------------------------
-- QUEUE COMPONENT
----------------------------------------------------------------

component QueueBase
    generic(
        name           : string;
        queue_depth    : integer;
        data_width     : integer;
        save_one_slot  : boolean
    );
    port(
        clk      : in  std_logic;
        reset    : in  std_logic;
        data_in  : in  std_logic_vector(data_width-1 downto 0);
        push_req : in  std_logic;
        push_ack : out std_logic;
        data_out : out std_logic_vector(data_width-1 downto 0);
        pop_ack  : out std_logic;
        pop_req  : in  std_logic
    );
end component;

begin

----------------------------------------------------------------
-- Queue
----------------------------------------------------------------

queue_inst_port_out_1_in_1 : QueueBase
generic map(
    name           => "shared",
    queue_depth    => QUEUE_DEPTH,
    data_width     => DATA_WIDTH,
    save_one_slot  => false
)
port map(
    clk      => clk,
    reset    => reset,
    data_in  => q_data_in_out1_in1,
    push_req => q_push_req_out1_in1,
    push_ack => q_push_ack_out1_in1,
    data_out => q_data_out_out1_in1,
    pop_ack  => q_pop_ack_out1_in1,
    pop_req  => q_pop_req_out1_in1
);

queue_inst_port_out_1_in_2 : QueueBase
generic map(
    name           => "shared",
    queue_depth    => QUEUE_DEPTH,
    data_width     => DATA_WIDTH,
    save_one_slot  => false
)
port map(
    clk      => clk,
    reset    => reset,
    data_in  => q_data_in_out1_in2,
    push_req => q_push_req_out1_in2,
    push_ack => q_push_ack_out1_in2,
    data_out => q_data_out_out1_in2,
    pop_ack  => q_pop_ack_out1_in2,
    pop_req  => q_pop_req_out1_in2
);

queue_inst_port_out_2_in_1 : QueueBase
generic map(
    name           => "shared",
    queue_depth    => QUEUE_DEPTH,
    data_width     => DATA_WIDTH,
    save_one_slot  => false
)
port map(
    clk      => clk,
    reset    => reset,
    data_in  => q_data_in_out2_in1,
    push_req => q_push_req_out2_in1,
    push_ack => q_push_ack_out2_in1,
    data_out => q_data_out_out2_in1,
    pop_ack  => q_pop_ack_out2_in1,
    pop_req  => q_pop_req_out2_in1
);

queue_inst_port_out_2_in_2 : QueueBase
generic map(
    name           => "shared",
    queue_depth    => QUEUE_DEPTH,
    data_width     => DATA_WIDTH,
    save_one_slot  => false
)
port map(
    clk      => clk,
    reset    => reset,
    data_in  => q_data_in_out2_in2,
    push_req => q_push_req_out2_in2,
    push_ack => q_push_ack_out2_in2,
    data_out => q_data_out_out2_in2,
    pop_ack  => q_pop_ack_out2_in2,
    pop_req  => q_pop_req_out2_in2
);


----------------------------------------------------------------
-- INPUT FSM REGISTER
----------------------------------------------------------------

process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            state_3 <= IDLE_3;
            state_4 <= IDLE_4;
            length_header_1 <= (others => '0');
            length_header_2 <= (others => '0');

        else

            state_3 <= next_state_3;
            state_4 <= next_state_4;

            case state_3 is

                when IDLE_3 =>
                    if (in_data_1_pipe_write_data(24) = '1') then
                        if (q_push_ack_out1_in1 = '1' and q_push_req_out1_in1 = '1') then
                            length_header_1 <= unsigned(q_data_in_out1_in1(23 downto 8)) - 1;
                        else
                            length_header_1 <= length_header_1;
                        end if;
                    else
                        if (q_push_ack_out2_in1 = '1' and q_push_req_out2_in1 = '1') then
                            length_header_1 <= unsigned(q_data_in_out2_in1(23 downto 8)) - 1;
                        else
                            length_header_1 <= length_header_1;
                        end if;
                    end if;

                when GO_A_1 =>
                    if (q_push_ack_out1_in1 = '1' and q_push_req_out1_in1 = '1') then
                        if (length_header_1 > 0) then
                            length_header_1 <= length_header_1 - 1;
                        end if;
                    end if;

                when GO_B_1 =>
                    if (q_push_ack_out2_in1 = '1' and q_push_req_out2_in1 = '1') then
                        if (length_header_1 > 0) then
                            length_header_1 <= length_header_1 - 1;
                        end if;
                    end if;

                when others =>
                    null;

            end case;


            case state_4 is

                when IDLE_4 =>
                    if (in_data_2_pipe_write_data(24) = '1') then
                        if (q_push_ack_out1_in2 = '1' and q_push_req_out1_in2 = '1') then
                            length_header_2 <= unsigned(q_data_in_out1_in2(23 downto 8)) - 1;
                        else
                            length_header_2 <= length_header_2;
                        end if;
                    else
                        if (q_push_ack_out2_in2 = '1' and q_push_req_out2_in2 = '1') then
                            length_header_2 <= unsigned(q_data_in_out2_in2(23 downto 8)) - 1;
                        else
                            length_header_2 <= length_header_2;
                        end if;
                    end if;

                when GO_A_2 =>
                    if (q_push_ack_out1_in2 = '1' and q_push_req_out1_in2 = '1') then
                        if (length_header_2 > 0) then
                            length_header_2 <= length_header_2 - 1;
                        end if;
                    end if;

                when GO_B_2 =>
                    if (q_push_ack_out2_in2 = '1' and q_push_req_out2_in2 = '1') then
                        if (length_header_2 > 0) then
                            length_header_2 <= length_header_2 - 1;
                        end if;
                    end if;

                when others =>
                    null;

            end case;

        end if;
    end if;
end process;

----------------------------------------------------------------
-- INPUT OUTPUT LOGIC
----------------------------------------------------------------

process(
    state_3, state_4,
    in_data_1_pipe_write_req, in_data_2_pipe_write_req,
    in_data_1_pipe_write_data, in_data_2_pipe_write_data,
    q_push_ack_out1_in1, q_push_ack_out2_in1,
    q_push_ack_out1_in2, q_push_ack_out2_in2
)
begin
    q_push_req_out1_in1 <= '0';
    q_push_req_out2_in1 <= '0';
    q_push_req_out1_in2 <= '0';
    q_push_req_out2_in2 <= '0';
    in_data_1_pipe_write_ack <= (others => '0');
    in_data_2_pipe_write_ack <= (others => '0');

    q_data_in_out1_in1 <= in_data_1_pipe_write_data;
    q_data_in_out2_in1 <= in_data_1_pipe_write_data;
    q_data_in_out1_in2 <= in_data_2_pipe_write_data;
    q_data_in_out2_in2 <= in_data_2_pipe_write_data;

    case state_3 is

        when IDLE_3 =>
            if (in_data_1_pipe_write_data(24) = '1' and
                in_data_1_pipe_write_req(0) = '1' and
                q_push_ack_out1_in1 = '1') then

                q_push_req_out1_in1 <= '1';
                in_data_1_pipe_write_ack(0) <= '1';

            elsif (in_data_1_pipe_write_data(24) = '0' and
                   in_data_1_pipe_write_req(0) = '1' and
                   q_push_ack_out2_in1 = '1') then

                q_push_req_out2_in1 <= '1';
                in_data_1_pipe_write_ack(0) <= '1';

            end if;

        when GO_A_1 =>
            in_data_1_pipe_write_ack(0) <= q_push_ack_out1_in1;

            if (in_data_1_pipe_write_req(0) = '1' and
                q_push_ack_out1_in1 = '1') then

                q_push_req_out1_in1 <= '1';
            end if;

        when GO_B_1 =>
            in_data_1_pipe_write_ack(0) <= q_push_ack_out2_in1;

            if (in_data_1_pipe_write_req(0) = '1' and
                q_push_ack_out2_in1 = '1') then

                q_push_req_out2_in1 <= '1';
            end if;

        when others =>
            null;

    end case;


    case state_4 is

        when IDLE_4 =>
            if (in_data_2_pipe_write_data(24) = '1' and
                in_data_2_pipe_write_req(0) = '1' and
                q_push_ack_out1_in2 = '1') then

                q_push_req_out1_in2 <= '1';
                in_data_2_pipe_write_ack(0) <= '1';

            elsif (in_data_2_pipe_write_data(24) = '0' and
                   in_data_2_pipe_write_req(0) = '1' and
                   q_push_ack_out2_in2 = '1') then

                q_push_req_out2_in2 <= '1';
                in_data_2_pipe_write_ack(0) <= '1';

            end if;

        when GO_A_2 =>
            in_data_2_pipe_write_ack(0) <= q_push_ack_out1_in2;

            if (in_data_2_pipe_write_req(0) = '1' and
                q_push_ack_out1_in2 = '1') then

                q_push_req_out1_in2 <= '1';
            end if;

        when GO_B_2 =>
            in_data_2_pipe_write_ack(0) <= q_push_ack_out2_in2;

            if (in_data_2_pipe_write_req(0) = '1' and
                q_push_ack_out2_in2 = '1') then

                q_push_req_out2_in2 <= '1';
            end if;

        when others =>
            null;

    end case;

end process;

----------------------------------------------------------------
-- INPUT NEXT STATE
----------------------------------------------------------------

process(
    state_3, state_4,
    in_data_1_pipe_write_data,
    in_data_1_pipe_write_req,
    in_data_2_pipe_write_data,
    in_data_2_pipe_write_req,
    q_push_ack_out1_in1,
    q_push_ack_out2_in1,
    q_push_ack_out1_in2,
    q_push_ack_out2_in2,
    length_header_1,
    length_header_2
)
begin

    next_state_3 <= state_3;
    next_state_4 <= state_4;

    case state_3 is

        when IDLE_3 =>
            if (in_data_1_pipe_write_data(24) = '1' and 
                in_data_1_pipe_write_req(0) = '1' and 
                q_push_ack_out1_in1 = '1') then
                next_state_3 <= GO_A_1;

            elsif (in_data_1_pipe_write_data(24) = '0' and 
                   in_data_1_pipe_write_req(0) = '1' and 
                   q_push_ack_out2_in1 = '1') then
                next_state_3 <= GO_B_1;

            else
                next_state_3 <= IDLE_3;
            end if;

        when GO_A_1 =>
            if (length_header_1 = 1 and 
                q_push_ack_out1_in1 = '1' and 
                in_data_1_pipe_write_req(0) = '1') then
                next_state_3 <= IDLE_3;
            end if;

        when GO_B_1 =>

            if (length_header_1 = 1 and 
                q_push_ack_out2_in1 = '1' and 
                in_data_1_pipe_write_req(0) = '1') then
                next_state_3 <= IDLE_3;
            end if;

        when others =>
            null;

    end case;


    case state_4 is

        when IDLE_4 =>
            if (in_data_2_pipe_write_data(24) = '1' and 
                in_data_2_pipe_write_req(0) = '1' and 
                q_push_ack_out1_in2 = '1') then
                next_state_4 <= GO_A_2;

            elsif (in_data_2_pipe_write_data(24) = '0' and 
                   in_data_2_pipe_write_req(0) = '1' and 
                   q_push_ack_out2_in2 = '1') then
                next_state_4 <= GO_B_2;

            else
                next_state_4 <= IDLE_4;
            end if;

        when GO_A_2 =>
            if (length_header_2 = 1 and 
                q_push_ack_out1_in2 = '1' and 
                in_data_2_pipe_write_req(0) = '1') then
                next_state_4 <= IDLE_4;
            end if;

        when GO_B_2 =>
            if (length_header_2 = 1 and 
                q_push_ack_out2_in2 = '1' and 
                in_data_2_pipe_write_req(0) = '1') then
                next_state_4 <= IDLE_4;
            end if;

        when others =>
            null;

    end case;

end process;

----------------------------------------------------------------
--OUTPUT ARBITER LOGIC
----------------------------------------------------------------

---output interface 1

process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            state_1 <= IDLE_1;
            state_2 <= IDLE_2;
            length_cnt_1 <= (others => '0');
            length_cnt_2 <= (others => '0');
            last_served_1 <= '0';
            last_served_2 <= '0';
        else

            state_1 <= next_state_1;
            state_2 <= next_state_2;
            last_served_1 <= last_served_next_1;
            last_served_2 <= last_served_next_2;

            case state_1 is

                when IDLE_1 =>
                    if (q_pop_ack_out1_in1 = '1' and next_state_1 = SERVE_A_1) then
                        length_cnt_1 <= unsigned(q_data_out_out1_in1(23 downto 8));
                    elsif (q_pop_ack_out1_in2 = '1' and next_state_1 = SERVE_B_1) then
                        length_cnt_1 <= unsigned(q_data_out_out1_in2(23 downto 8));
                    end if;

                when SERVE_A_1 =>
                    if (q_pop_req_out1_in1 = '1' and q_pop_ack_out1_in1 = '1') then
                        if length_cnt_1 > 0 then
                            length_cnt_1 <= length_cnt_1 - 1;
                        end if;
                    end if;

                when SERVE_B_1 =>
                    if (q_pop_req_out1_in2 = '1' and q_pop_ack_out1_in2 = '1') then
                        if length_cnt_1 > 0 then
                            length_cnt_1 <= length_cnt_1 - 1;
                        end if;
                    end if;

            end case;

            case state_2 is

                when IDLE_2 =>
                    if (q_pop_ack_out2_in1 = '1' and next_state_2 = SERVE_A_2) then
                        length_cnt_2 <= unsigned(q_data_out_out2_in1(23 downto 8));
                    elsif (q_pop_ack_out2_in2 = '1' and next_state_2 = SERVE_B_2) then
                        length_cnt_2 <= unsigned(q_data_out_out2_in2(23 downto 8));
                    end if;

                when SERVE_A_2 =>
                    if (q_pop_req_out2_in1 = '1' and q_pop_ack_out2_in1 = '1') then
                        if length_cnt_2 > 0 then
                            length_cnt_2 <= length_cnt_2 - 1;
                        end if;
                    end if;

                when SERVE_B_2 =>
                    if (q_pop_req_out2_in2 = '1' and q_pop_ack_out2_in2 = '1') then
                        if length_cnt_2 > 0 then
                            length_cnt_2 <= length_cnt_2 - 1;
                        end if;
                    end if;

            end case;

        end if;
    end if;
end process;

-----------------------------------------------------------------
-- OUTPUT DATA LOGIC
----------------------------------------------------------------

process(state_1, state_2,
        q_data_out_out1_in1, q_data_out_out1_in2,
        q_data_out_out2_in1, q_data_out_out2_in2,
        q_pop_ack_out1_in1, q_pop_ack_out1_in2,
        q_pop_ack_out2_in1, q_pop_ack_out2_in2,
        out_data_1_pipe_read_req,
        out_data_2_pipe_read_req)
begin

    out_data_1_pipe_read_data <= (others => '0');
    out_data_2_pipe_read_data <= (others => '0');

    out_data_1_pipe_read_ack <= (others => '0');
    out_data_2_pipe_read_ack <= (others => '0');

    q_pop_req_out1_in1 <= '0';
    q_pop_req_out1_in2 <= '0';
    q_pop_req_out2_in1 <= '0';
    q_pop_req_out2_in2 <= '0';

    case state_1 is
        when SERVE_A_1 =>
            out_data_1_pipe_read_data   <= q_data_out_out1_in1;
            out_data_1_pipe_read_ack(0) <= q_pop_ack_out1_in1;

            if (out_data_1_pipe_read_req(0) = '1' and q_pop_ack_out1_in1 = '1') then
                q_pop_req_out1_in1 <= '1';
            end if;

        when SERVE_B_1 =>
            out_data_1_pipe_read_data <= q_data_out_out1_in2;
            out_data_1_pipe_read_ack(0) <= q_pop_ack_out1_in2;

            if (out_data_1_pipe_read_req(0) = '1' and q_pop_ack_out1_in2 = '1') then
                q_pop_req_out1_in2 <= '1';
            end if;

        when others =>
            null;

    end case;

    case state_2 is

        when SERVE_A_2 =>
            out_data_2_pipe_read_data <= q_data_out_out2_in1;
            out_data_2_pipe_read_ack(0) <= q_pop_ack_out2_in1;

            if (out_data_2_pipe_read_req(0) = '1' and q_pop_ack_out2_in1 = '1') then
                q_pop_req_out2_in1 <= '1';
            end if;

        when SERVE_B_2 =>
            out_data_2_pipe_read_data <= q_data_out_out2_in2;
            out_data_2_pipe_read_ack(0) <= q_pop_ack_out2_in2;

            if (out_data_2_pipe_read_req(0) = '1' and q_pop_ack_out2_in2 = '1') then
                q_pop_req_out2_in2 <= '1';
            end if;

        when others =>
            null;

    end case;
end process;

----------------------------------------------------------------
-- NEXT STATE LOGIC
----------------------------------------------------------------

process(state_1, state_2,
        last_served_1, last_served_2,
        length_cnt_1, length_cnt_2)
begin
    next_state_1 <= state_1;
    next_state_2 <= state_2;
    last_served_next_1 <= last_served_1;
    last_served_next_2 <= last_served_2;

    case state_1 is

        when IDLE_1 =>
            if (last_served_1 = '1' and q_pop_ack_out1_in1 = '1') then
                next_state_1 <= SERVE_A_1;
                last_served_next_1 <= '0';
            else
                next_state_1 <= SERVE_B_1;
                last_served_next_1 <= '1';
            end if;

        when SERVE_A_1 =>
            if length_cnt_1 = 1 then
                next_state_1 <= IDLE_1;
            end if;

        when SERVE_B_1 =>
            if length_cnt_1 = 1 then
                next_state_1 <= IDLE_1;
            end if;

    end case;

    case state_2 is

        when IDLE_2 =>
            if (last_served_2 = '1' and q_pop_ack_out2_in1 = '1') then
                next_state_2 <= SERVE_A_2;
                last_served_next_2 <= '0';
            else
                next_state_2 <= SERVE_B_2;
                last_served_next_2 <= '1';
            end if;

        when SERVE_A_2 =>
            if length_cnt_2 = 1 then
                next_state_2 <= IDLE_2;
            end if;

        when SERVE_B_2 =>
            if length_cnt_2 = 1 then
                next_state_2 <= IDLE_2;
            end if;

    end case;

end process;


end architecture;