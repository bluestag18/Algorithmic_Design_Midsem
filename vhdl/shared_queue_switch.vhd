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

    type state_0 is (IDLE, SERVE_A, SERVE_B);
    type state_1 is (CHUMMA, OUT_A, OUT_B);
    signal state_in, next_state_in  : state_0;
    signal state_out, next_state_out : state_1;

    signal last_served : std_logic;

    signal length_cnt  : unsigned(15 downto 0);
    signal length_ded  : unsigned(15 downto 0);

    signal q_data_in  : std_logic_vector(31 downto 0);
    signal q_push_req : std_logic;
    signal q_push_ack : std_logic;

    signal q_data_out : std_logic_vector(31 downto 0);
    signal q_pop_req  : std_logic;
    signal q_pop_ack  : std_logic;

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

queue_inst : QueueBase
generic map(
    name           => "shared",
    queue_depth    => QUEUE_DEPTH,
    data_width     => DATA_WIDTH,
    save_one_slot  => false
)
port map(
    clk      => clk,
    reset    => reset,
    data_in  => q_data_in,
    push_req => q_push_req,
    push_ack => q_push_ack,
    data_out => q_data_out,
    pop_ack  => q_pop_ack,
    pop_req  => q_pop_req
);

----------------------------------------------------------------
-- INPUT FSM REGISTER
----------------------------------------------------------------

process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            state_in    <= IDLE;
            last_served <= '0';
            length_cnt  <= (others => '0');
        else
            state_in <= next_state_in;

            if (state_in = IDLE and q_push_ack = '1' and q_push_req = '1') then
                length_cnt <= unsigned(q_data_in(23 downto 8)) - 1;

                if next_state_in = SERVE_A then
                    last_served <= '0';
                elsif next_state_in = SERVE_B then
                    last_served <= '1';
                end if;

            elsif (q_push_req = '1' and q_push_ack = '1') then
                if length_cnt > 0 then
                    length_cnt <= length_cnt - 1;
                end if;
            end if;

        end if;
    end if;
end process;

----------------------------------------------------------------
-- INPUT OUTPUT LOGIC
----------------------------------------------------------------

process(state_in, in_data_1_pipe_write_req, in_data_2_pipe_write_req,
        q_push_ack, in_data_1_pipe_write_data, in_data_2_pipe_write_data)
begin

    in_data_1_pipe_write_ack <= (others => '0');
    in_data_2_pipe_write_ack <= (others => '0');
    q_data_in  <= (others => '0');
    q_push_req <= '0';

    case state_in is

        when IDLE =>

            if q_push_ack = '1' then

                if (in_data_1_pipe_write_req(0) = '1' and in_data_2_pipe_write_req(0) = '0') then
                    q_data_in  <= in_data_1_pipe_write_data;
                    q_push_req <= '1';
                    in_data_1_pipe_write_ack(0) <= q_push_ack;

                elsif (in_data_1_pipe_write_req(0) = '0' and in_data_2_pipe_write_req(0) = '1') then
                    q_data_in  <= in_data_2_pipe_write_data;
                    q_push_req <= '1';
                    in_data_2_pipe_write_ack(0) <= q_push_ack;

                elsif (in_data_1_pipe_write_req(0) = '1' and in_data_2_pipe_write_req(0) = '1') then

                    if last_served = '0' then
                        q_push_req <= '1';
                        q_data_in  <= in_data_2_pipe_write_data;
                        in_data_2_pipe_write_ack(0) <= q_push_ack;
                    else
                        q_push_req <= '1';
                        q_data_in  <= in_data_1_pipe_write_data;
                        in_data_1_pipe_write_ack(0) <= q_push_ack;
                    end if;

                end if;

            end if;

        when SERVE_A =>
            in_data_1_pipe_write_ack(0) <= q_push_ack;
            q_data_in <= in_data_1_pipe_write_data;

            if (in_data_1_pipe_write_req(0) = '1' and q_push_ack = '1') then
                q_push_req <= '1';
            end if;

        when SERVE_B =>
            in_data_2_pipe_write_ack(0) <= q_push_ack;
            q_data_in <= in_data_2_pipe_write_data;

            if (in_data_2_pipe_write_req(0) = '1' and q_push_ack = '1') then
                q_push_req <= '1';
            end if;

        when others =>
            null;

    end case;

end process;

----------------------------------------------------------------
-- INPUT NEXT STATE
----------------------------------------------------------------

process(state_in, in_data_1_pipe_write_req, in_data_2_pipe_write_req,
        q_push_ack, length_cnt, last_served)
begin

    next_state_in <= state_in;

    case state_in is

        when IDLE =>

            if (in_data_1_pipe_write_req(0) = '1' and in_data_2_pipe_write_req(0) = '0' and q_push_ack = '1') then
                next_state_in <= SERVE_A;

            elsif (in_data_1_pipe_write_req(0) = '0' and in_data_2_pipe_write_req(0) = '1' and q_push_ack = '1') then
                next_state_in <= SERVE_B;

            elsif (in_data_1_pipe_write_req(0) = '1' and in_data_2_pipe_write_req(0) = '1' and q_push_ack = '1') then

                if last_served = '0' then
                    next_state_in <= SERVE_B;
                else
                    next_state_in <= SERVE_A;
                end if;

            end if;

        when SERVE_A =>

            if (length_cnt = 1 and q_push_ack = '1' and in_data_1_pipe_write_req(0) = '1') then
                next_state_in <= IDLE;
            end if;

        when SERVE_B =>

            if (length_cnt = 1 and q_push_ack = '1' and in_data_2_pipe_write_req(0) = '1') then
                next_state_in <= IDLE;
            end if;

        when others =>
            null;

    end case;

end process;

----------------------------------------------------------------
-- OUTPUT FSM REGISTER
----------------------------------------------------------------

process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            state_out <= CHUMMA;
            length_ded <= (others => '0');
        else
            state_out <= next_state_out;

            if (state_out = CHUMMA and q_pop_ack = '1') then
                length_ded <= unsigned(q_data_out(23 downto 8));

            elsif (q_pop_req = '1' and q_pop_ack = '1') then
                if length_ded > 0 then
                    length_ded <= length_ded - 1;
                end if;
            end if;

        end if;
    end if;
end process;

----------------------------------------------------------------
-- OUTPUT DATA LOGIC
----------------------------------------------------------------

process(state_out, q_data_out, q_pop_ack,
        out_data_1_pipe_read_req, out_data_2_pipe_read_req)
begin

    out_data_1_pipe_read_data <= (others => '0');
    out_data_1_pipe_read_ack  <= (others => '0');
    out_data_2_pipe_read_data <= (others => '0');
    out_data_2_pipe_read_ack  <= (others => '0');

    q_pop_req <= '0';

    case state_out is

        when OUT_A =>

            out_data_1_pipe_read_data <= q_data_out;
            out_data_1_pipe_read_ack(0) <= q_pop_ack;

            if (out_data_1_pipe_read_req(0) = '1' and q_pop_ack = '1') then
                q_pop_req <= '1';
            end if;

        when OUT_B =>

            out_data_2_pipe_read_data <= q_data_out;
            out_data_2_pipe_read_ack(0) <= q_pop_ack;

            if (out_data_2_pipe_read_req(0) = '1' and q_pop_ack = '1') then
                q_pop_req <= '1';
            end if;

        when others =>
            null;

    end case;

end process;

----------------------------------------------------------------
-- OUTPUT NEXT STATE
----------------------------------------------------------------

process(state_out, q_pop_ack, q_data_out,
        length_ded, out_data_1_pipe_read_req, out_data_2_pipe_read_req)
begin

    next_state_out <= state_out;

    case state_out is

        when CHUMMA =>

            if (q_pop_ack = '1' and q_data_out(24) = '1') then
                next_state_out <= OUT_A;

            elsif (q_pop_ack = '1' and q_data_out(24) = '0') then
                next_state_out <= OUT_B;

            end if;

        when OUT_A =>

            if (length_ded = 1 and out_data_1_pipe_read_req(0) = '1' and q_pop_ack = '1') then
                next_state_out <= CHUMMA;
            end if;

        when OUT_B =>

            if (length_ded = 1 and out_data_2_pipe_read_req(0) = '1' and q_pop_ack = '1') then
                next_state_out <= CHUMMA;
            end if;

        when others =>
            next_state_out <= CHUMMA;

    end case;

end process;

end architecture;