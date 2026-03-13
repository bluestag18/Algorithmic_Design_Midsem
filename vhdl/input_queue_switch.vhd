library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity switch_2x2 is
    generic (
        DATA_WIDTH  : integer := 32;
        QUEUE_DEPTH : integer := 1024
    );
    port (
        clk  : in std_logic;
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

    type state_type_0 is (IDLE_1, SERVE_A_1, SERVE_B_1);
    type state_type_1 is (IDLE_2, SERVE_A_2, SERVE_B_2);

    signal state_1, next_state_1 : state_type_0;
    signal state_2, next_state_2 : state_type_1;

    signal last_served : std_logic;
    signal last_served_next : std_logic;

    signal length_cnt_1 : unsigned(15 downto 0);
    signal length_cnt_2 : unsigned(15 downto 0);

    signal busy_1 : std_logic;
    signal busy_2 : std_logic;

    signal q_data_in_1  : std_logic_vector(31 downto 0);
    signal q_data_in_2  : std_logic_vector(31 downto 0);

    signal q_push_req_1 : std_logic;
    signal q_push_req_2 : std_logic;

    signal q_push_ack_1 : std_logic;
    signal q_push_ack_2 : std_logic;

    signal q_data_out_1 : std_logic_vector(31 downto 0);
    signal q_data_out_2 : std_logic_vector(31 downto 0);

    signal q_pop_req_1 : std_logic;
    signal q_pop_req_2 : std_logic;

    signal q_pop_ack_1 : std_logic;
    signal q_pop_ack_2 : std_logic;

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
-- Queue instances
----------------------------------------------------------------

queue_inst_1 : QueueBase
generic map(
    name => "shared",
    queue_depth => QUEUE_DEPTH,
    data_width => DATA_WIDTH,
    save_one_slot => false
)
port map(
    clk => clk,
    reset => reset,
    data_in => q_data_in_1,
    push_req => q_push_req_1,
    push_ack => q_push_ack_1,
    data_out => q_data_out_1,
    pop_ack => q_pop_ack_1,
    pop_req => q_pop_req_1
);

queue_inst_2 : QueueBase
generic map(
    name => "shared",
    queue_depth => QUEUE_DEPTH,
    data_width => DATA_WIDTH,
    save_one_slot => false
)
port map(
    clk => clk,
    reset => reset,
    data_in => q_data_in_2,
    push_req => q_push_req_2,
    push_ack => q_push_ack_2,
    data_out => q_data_out_2,
    pop_ack => q_pop_ack_2,
    pop_req => q_pop_req_2
);

----------------------------------------------------------------
-- INPUT PROCESS
----------------------------------------------------------------

process(in_data_1_pipe_write_req, in_data_2_pipe_write_req,
        q_push_ack_1, q_push_ack_2,
        in_data_1_pipe_write_data, in_data_2_pipe_write_data)
begin

    in_data_1_pipe_write_ack(0) <= q_push_ack_1;
    in_data_2_pipe_write_ack(0) <= q_push_ack_2;

    q_data_in_1 <= in_data_1_pipe_write_data;
    q_data_in_2 <= in_data_2_pipe_write_data;

    if (q_push_ack_1 = '1' and in_data_1_pipe_write_req(0) = '1') then
        q_push_req_1 <= '1';
    else
        q_push_req_1 <= '0';
    end if;

    if (q_push_ack_2 = '1' and in_data_2_pipe_write_req(0) = '1') then
        q_push_req_2 <= '1';
    else
        q_push_req_2 <= '0';
    end if;

end process;

----------------------------------------------------------------
-- OUTPUT FSM REGISTER
----------------------------------------------------------------

process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            state_1 <= IDLE_1;
            state_2 <= IDLE_2;
            length_cnt_1 <= (others => '0');
            length_cnt_2 <= (others => '0');
            last_served <= '0';
        else

            state_1 <= next_state_1;
            state_2 <= next_state_2;
            last_served <= last_served_next;

            if (state_1 = IDLE_1 and q_pop_ack_1 = '1') then
                length_cnt_1 <= unsigned(q_data_out_1(23 downto 8));

            elsif (q_pop_req_1 = '1' and q_pop_ack_1 = '1') then
                if length_cnt_1 > 0 then
                    length_cnt_1 <= length_cnt_1 - 1;
                end if;
            end if;

            if (state_2 = IDLE_2 and q_pop_ack_2 = '1') then
                length_cnt_2 <= unsigned(q_data_out_2(23 downto 8));

            elsif (q_pop_req_2 = '1' and q_pop_ack_2 = '1') then
                if length_cnt_2 > 0 then
                    length_cnt_2 <= length_cnt_2 - 1;
                end if;
            end if;

        end if;
    end if;
end process;

----------------------------------------------------------------
-- OUTPUT DATA LOGIC
----------------------------------------------------------------

process(state_1, state_2,
        q_data_out_1, q_data_out_2,
        q_pop_ack_1, q_pop_ack_2,
        out_data_1_pipe_read_req,
        out_data_2_pipe_read_req)
begin

    busy_1 <= '0';
    busy_2 <= '0';

    out_data_1_pipe_read_data <= (others => '0');
    out_data_2_pipe_read_data <= (others => '0');

    out_data_1_pipe_read_ack <= (others => '0');
    out_data_2_pipe_read_ack <= (others => '0');

    q_pop_req_1 <= '0';
    q_pop_req_2 <= '0';

    case state_1 is

        when SERVE_A_1 =>
            busy_1 <= '1';

            out_data_1_pipe_read_data <= q_data_out_1;
            out_data_1_pipe_read_ack(0) <= q_pop_ack_1;

            if (out_data_1_pipe_read_req(0) = '1' and q_pop_ack_1 = '1') then
                q_pop_req_1 <= '1';
            end if;

        when SERVE_B_1 =>
            busy_2 <= '1';

            out_data_2_pipe_read_data <= q_data_out_1;
            out_data_2_pipe_read_ack(0) <= q_pop_ack_1;

            if (out_data_2_pipe_read_req(0) = '1' and q_pop_ack_1 = '1') then
                q_pop_req_1 <= '1';
            end if;

        when others =>
            null;

    end case;

    case state_2 is

        when SERVE_A_2 =>
            busy_1 <= '1';

            out_data_1_pipe_read_data <= q_data_out_2;
            out_data_1_pipe_read_ack(0) <= q_pop_ack_2;

            if (out_data_1_pipe_read_req(0) = '1' and q_pop_ack_2 = '1') then
                q_pop_req_2 <= '1';
            end if;

        when SERVE_B_2 =>
            busy_2 <= '1';

            out_data_2_pipe_read_data <= q_data_out_2;
            out_data_2_pipe_read_ack(0) <= q_pop_ack_2;

            if (out_data_2_pipe_read_req(0) = '1' and q_pop_ack_2 = '1') then
                q_pop_req_2 <= '1';
            end if;

        when others =>
            null;

    end case;

end process;

----------------------------------------------------------------
-- NEXT STATE LOGIC
----------------------------------------------------------------

process(state_1, state_2,
        q_data_out_1, q_data_out_2,
        busy_1, busy_2,
        last_served,
        length_cnt_1, length_cnt_2)
begin

    next_state_1 <= state_1;
    next_state_2 <= state_2;
    last_served_next <= last_served;

    case state_1 is

        when IDLE_1 =>

            if (q_data_out_1(24) = '1' and busy_1 = '0') then

                if (state_2 = IDLE_2 and q_data_out_2(24) = '1') then
                    if last_served = '1' then
                        next_state_1 <= SERVE_A_1;
                        last_served_next <= '0';
                    end if;
                else
                    next_state_1 <= SERVE_A_1;
                end if;

            elsif (q_data_out_1(24) = '0' and busy_2 = '0') then

                if (state_2 = IDLE_2 and q_data_out_2(24) = '0') then
                    if last_served = '1' then
                        next_state_1 <= SERVE_B_1;
                        last_served_next <= '0';
                    end if;
                else
                    next_state_1 <= SERVE_B_1;
                end if;

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

            if (q_data_out_2(24) = '1' and busy_1 = '0') then

                if (state_1 = IDLE_1 and q_data_out_1(24) = '1') then
                    if last_served = '0' then
                        next_state_2 <= SERVE_A_2;
                        last_served_next <= '1';
                    end if;
                else
                    next_state_2 <= SERVE_A_2;
                end if;

            elsif (q_data_out_2(24) = '0' and busy_2 = '0') then

                if (state_1 = IDLE_1 and q_data_out_1(24) = '0') then
                    if last_served = '0' then
                        next_state_2 <= SERVE_B_2;
                        last_served_next <= '1';
                    end if;
                else
                    next_state_2 <= SERVE_B_2;
                end if;

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