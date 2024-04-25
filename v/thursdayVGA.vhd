library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.dw.all;


entity thursdayVGA is
  port(
    MAX10_CLK1_50 : in    std_logic;
    ADC_CLK_10    : in    std_logic;
    KEY           : in    std_logic_vector (1 downto 0);
    VGA_HS        : out   std_logic;
    VGA_VS        : out   std_logic;
    VGA_R         : out   std_logic_vector (3 downto 0);
    VGA_G         : out   std_logic_vector (3 downto 0);
    VGA_B         : out   std_logic_vector (3 downto 0);
    LEDR          : out   std_logic_vector (9 downto 0);  -- debug LEDS
    GPIO          : inout std_logic_vector (35 downto 0)  -- some IO for audio etc
    );
end thursdayVGA;
architecture RTL of thursdayVGA is

-- sync generator component for VGA signals
  component video_sync_generator port
                                   (
                                     reset   : in  std_logic;
                                     vga_clk : in  std_logic;
                                     blank_n : out std_logic;
                                     HS      : out std_logic;
                                     VS      : out std_logic;
                                     xPos    : out std_logic_vector (10 downto 0);
                                     yPos    : out std_logic_vector (9 downto 0)
                                     );
  end component;
  component vidclk
    port
      (
        inclk0 : in  std_logic := '0';
        c0     : out std_logic
        );
  end component;
  component txtScreen
--       generic(); -- pixel position
    port(
      hp, vp :    integer;
      addr   : in std_logic_vector(11 downto 0);  -- text screen ram
      data   : in std_logic_vector(7 downto 0);
      nWr    : in std_logic;
      pClk   : in std_logic;
      nblnk  : in std_logic;

      pix : out std_logic

      );
  end component;
  component paddles
    port (
      CLOCK : in  std_logic := 'X';               -- clk
      RESET : in  std_logic := 'X';               -- reset
      CH0   : out std_logic_vector(11 downto 0);  -- CH0
      CH1   : out std_logic_vector(11 downto 0);  -- CH1
      CH2   : out std_logic_vector(11 downto 0);  -- CH2
      CH3   : out std_logic_vector(11 downto 0);  -- CH3
      CH4   : out std_logic_vector(11 downto 0);  -- CH4
      CH5   : out std_logic_vector(11 downto 0);  -- CH5
      CH6   : out std_logic_vector(11 downto 0);  -- CH6
      CH7   : out std_logic_vector(11 downto 0)   -- CH7
      );
  end component paddles;
  type t_Integer_Array is array (integer range <>) of integer;
-- sprite for ball
  signal ball : t_Integer_Array(0 to 99) :=
    (0, 0, 0, 1, 1, 1, 1, 0, 0, 0,
     0, 0, 1, 1, 1, 1, 1, 1, 0, 0,
     0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
     1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
     1, 1, 1, 1, 2, 2, 1, 1, 1, 1,
     1, 1, 1, 1, 2, 2, 1, 1, 1, 1,
     1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
     0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
     0, 0, 1, 1, 1, 1, 1, 1, 0, 0,
     0, 0, 0, 1, 1, 1, 1, 0, 0, 0);
-- sprite for paddle
--  signal paddle : std_logic_vector( 19 downto 0) :=
--      ('1', '1',
--       '1', '1',
--       '1', '1',
--       '1', '1',
--       '1', '1',
--       '1', '1',
--       '1', '1',
--       '1', '1',
--       '1', '1',
--       '1', '1');


  signal RST         : std_logic;
  signal pixelclk    : std_logic;
  signal Blanking    : std_logic;
  signal hpos        : std_logic_vector(10 downto 0);
  signal vpos        : std_logic_vector(9 downto 0);
  signal pixelxpos   : integer range 0 to 639  := 0;
  signal pixelypos   : integer range 0 to 479  := 0;
  signal paddlePlyr1 : integer range 0 to 479  := 200;
  signal paddlePlyr2 : integer range 0 to 479  := 200;
  signal secondsCtr  : integer range 0 to 3600 := 0;
  signal seconds     : integer range 0 to 3600 := 0;

  signal xdotpos    : integer range 0 to 799  := 0;
  signal ydotpos    : integer range 0 to 524  := 0;
  signal ballsize   : integer range 0 to 10   := 10;
  signal ballx      : integer range 0 to 639  := 20;
  signal bally      : integer range 0 to 479  := 20;
  signal ballxdir   : integer range -1 to 1   := 1;
  signal ballydir   : integer range -1 to 1   := 1;
  signal ballxspd   : integer range -10 to 10 := 2;
  signal ballyspd   : integer range -10 to 10 := 2;
  signal drawbl     : std_logic_vector (1 downto 0);
  signal scaleBL    : integer range 0 to 100  := 1;
  signal VS         : std_logic;
  signal HS         : std_logic;
  signal txtaddress : std_logic_vector(11 downto 0);
  signal txtdata    : std_logic_vector(7 downto 0);
  signal wren       : std_logic;
  signal txtpixel   : std_logic;
  signal paddlepos1 : std_logic_vector (11 downto 0);
  signal paddlepos2 : std_logic_vector (11 downto 0);
  signal paddlepos3 : std_logic_vector (11 downto 0);
  signal paddlepos4 : std_logic_vector (11 downto 0);

  signal plyr1score    : integer := 0;
  signal plyr1setscore : integer := 0;
  signal plyr1wins     : integer := 0;
  signal plyr2score    : integer := 0;
  signal plyr2setscore : integer := 0;
  signal plyr2wins     : integer := 0;

  signal charpos : integer range 0 to 4191 := 0;  -- character position from start of screen memory
  signal tens1   : integer range 0 to 255  := 0;  -- player 1 BCD score
  signal unit1   : integer range 0 to 255  := 0;
  signal tens2   : integer range 0 to 255  := 0;  -- player 2 BCD score
  signal unit2   : integer range 0 to 255  := 0;
  signal games1  : integer range 0 to 255  := 0;  -- player 1 Sets score
  signal games2  : integer range 0 to 255  := 0;  -- player 2 Sets score


  signal cycle      : integer                 := 0;  -- memory write cycle
  signal debugCount : integer range 0 to 1047 := 0;  -- counter to help with debugging

  constant p1scpos : std_logic_vector (11 downto 0) := "000001011000";  -- 0x58
  constant p2scpos : std_logic_vector (11 downto 0) := "000001101100";  -- 0x6c

  signal plyr1serve : std_logic;

  signal blipcounter : integer range 0 to 100000000 := 0;
  signal blopcounter : integer range 0 to 100000000 := 0;
  signal blip        : std_logic;
  signal blop        : std_logic;
  signal blipping    : std_logic;
  signal blopping    : std_logic;

  signal audio : std_logic;

begin

  RST       <= not KEY(0);
  xdotpos   <= (to_integer(unsigned(hpos)));  -- make numerical
  ydotpos   <= (to_integer(unsigned(vpos)));
  pixelxpos <= xdotpos - 144;                 -- back porch offset
  pixelypos <= ydotpos - 34;
  VGA_VS    <= VS;
  VGA_HS    <= HS;

  vidclk_inst : vidclk port map (
    inclk0 => max10_CLK1_50,
    c0     => pixelclk
    );

  syncgeninst : component video_sync_generator port map (
    rst,
    pixelclk,
    blanking,
    HS,
    VS,
    hpos,
    vpos
    );
  txtscreenInst : component txtscreen port map (
    pixelxpos,
    pixelypos,
    txtaddress,
    txtdata,
    wren,
    pixelclk,
    blanking,
    txtpixel
    );
  u0 : component paddles
    port map (
      CLOCK => ADC_CLK_10,              --      clk.clk
      RESET => rst,                     --    reset.reset
      CH0   => paddlepos1,              -- readings.CH0
      CH1   => paddlepos2,              --         .CH1
      CH2   => paddlepos3,              --         .CH2
      CH3   => paddlepos4               --         .CH3
--                      CH4   => CONNECTED_TO_CH4,   --         .CH4
--                      CH5   => CONNECTED_TO_CH5,   --         .CH5
--                      CH6   => CONNECTED_TO_CH6,   --         .CH6
--                      CH7   => CONNECTED_TO_CH7    --         .CH7
      );
  process(pixelclk) is
  begin
    if (falling_edge(pixelclk)) then
      -- ball sprite
--   SP(pixelxpos, pixelypos, ballx, bally, ball, scaleBL, DRAWBL);
      if(pixelxpos-ballx)/scaleBL >= -5 and (pixelxpos-ballx)/scaleBL < 5 and (pixelypos-bally)/scaleBL >= -5 and (pixelypos-bally)/scaleBL < 5 then
        if ball(5+((pixelxpos-ballx)/scaleBL) + ((5+((pixelypos-bally)/scaleBL))*10)) = 1 then
          DRAWBL <= "11";
        elsif ball(5+((pixelxpos-ballx)/scaleBL) + ((5+((pixelypos-bally)/scaleBL))*10)) = 2 then
          DRAWBL <= "10";
        else
          DRAWBL <= "00";
        end if;
      else
        DRAWBL <= "00";
      end if;

    end if;
  end process;
  -- Enumerate the digits of the scores
  tens1  <= 48 + ((plyr1score / 10) mod 10);
  unit1  <= 48 + (plyr1score mod 10);
  tens2  <= 48 + ((plyr2score / 10) mod 10);
  unit2  <= 48 + (plyr2score mod 10);
  games1 <= 48 + plyr1setscore mod 10;
  games2 <= 48 + plyr2setscore mod 10;

  gpio(9)  <= audio;
  gpio(21) <= audio;
  gpio(23) <= blip;
  gpio(25) <= blipping;

  process(max10_clk1_50)
  begin  -- make some noise
    if (rising_edge(max10_clk1_50)) then
      if rst = '1' then                 -- silence
        blipping <= '0';
        blopping <= '0';
      else
        if (blip = '1') then
          blipping <= '1';
        end if;
        if (blop = '1') then
          blopping <= '1';
        end if;
        if (blipping = '1') then

          ledr(5)     <= '0';
          blipcounter <= blipcounter + 1;
          if (blipcounter mod 25000) = 1 then
            audio <= not audio;         -- 800 Hz
          end if;
          if (blipcounter > 5000000) then
            blipping    <= '0';
            blipcounter <= 0;
            audio       <= '0';         -- silence beeper
          end if;
        end if;
        if (blopping = '1') then

          blopcounter <= blopcounter + 1;
          if (blopcounter mod 50000) = 1 then
            audio <= not audio;         -- 400 Hz
          end if;
          if (blopcounter > 5000000) then
            blopping    <= '0';
            blopcounter <= 0;
            audio       <= '0';         -- silence beeper
          end if;
        end if;
      end if;
    end if;
  end process;

  process(max10_clk1_50)
  begin  -- update the display with player scores
    if (rising_edge(max10_clk1_50)) then
      if rst = '1' then
        txtaddress <= "000000000000";
        txtdata    <= "00000000";
        wren       <= '0';
        cycle      <= 0;
        charpos    <= 0;
      else
        if cycle = 0 then               -- state machine for writing to text
          -- memory with ascii code values
          cycle      <= 1;
          wren       <= '0';
          txtAddress <= std_logic_vector(to_unsigned(charpos, txtAddress'length));
          if charpos = 88 then
            txtdata <= std_logic_vector(to_unsigned(tens1, txtdata'length));  -- write p1 tens to display
          elsif charpos = 89 then
            txtdata <= std_logic_vector(to_unsigned(unit1, txtdata'length));  -- write p1 units to display
          elsif charpos = 98 then
            txtdata <= std_logic_vector(to_unsigned(games1, txtdata'length));  -- write p1 units to display
          elsif charpos = 101 then
            txtdata <= std_logic_vector(to_unsigned(games2, txtdata'length));  -- write p1 units to display
          elsif charpos = 110 then
            txtdata <= std_logic_vector(to_unsigned(tens2, txtdata'length));  -- write p2 tens to display
          elsif charpos = 111 then
            txtdata <= std_logic_vector(to_unsigned(unit2, txtdata'length));  -- write p2 units to display
          else cycle <= 2;
          end if;

        elsif cycle = 1 then            -- strobe wren high for one clock
          wren  <= '1';
          cycle <= 2;
        else                  -- cycle is 2, reset cycle and increment
          -- memory address for next
          -- character position
          wren  <= '0';
          cycle <= 0;
          if charpos < 1023 then
            charpos <= charpos + 1;
          else
            charpos <= 0;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Draw stuff to the display
  process(pixelclk, rst, blanking)
  begin
    if ((rst = '1') or (blanking = '0')) then
      vga_r <= "0000";
      vga_g <= "0000";
      vga_b <= "0000";
    elsif (rising_edge(pixelclk)) then

-- Background and text section
      if ((pixelypos >= 105) and (pixelypos <= 475)) then
        if (pixelxpos >= 319) and (pixelxpos <= 321) and (((pixelypos/8) mod 2) = 0) then
-- draw the net 
          vga_r <= "1010";
          vga_g <= "1010";
          vga_b <= "1010";
        else
-- draw the grass
          vga_r <= "0001";
          vga_g <= "0111"
          vga_b <= "0001";
        end if;
-- draw the sidelines
      elsif ((pixelypos > 100) and (pixelypos < 105)) or
        ((pixelypos > 475) and (pixelypos < 479)) then
        vga_r <= "1111";
        vga_g <= "1111";
        vga_b <= "1111";
-- Draw text pixels when required
      elsif (txtpixel = '1') then
        vga_r <= "1111";
        vga_g <= "1111";
        vga_b <= "0000";
-- Don't draw any blank areas
      else
        vga_r <= "0000";
        vga_g <= "0000";
        vga_b <= "0000";

      end if;
-- Draw the ball at current position
      if (drawbl = "11") then
--      if (ballx >= pixelxpos) and (ballx < pixelxpos + ballsize) and
--        (bally >= pixelypos) and (bally < pixelypos + ballsize) then
--        if (ball((pixelxpos - ballx) + (10 * (pixelypos - bally))-29) = '1') then
        vga_r <= "1111";
        vga_g <= "1111";
        vga_b <= "1111";
--        end if;
      elsif (drawbl = "10") then
        vga_r <= "1111";
        vga_g <= "0000";
        vga_b <= "1111";

      end if;
-- Draw the paddles
      if (paddleplyr1 > pixelypos - 15) and
        (paddleplyr1 < pixelypos + 15) and
        (pixelxpos > 20) and
        (pixelxpos < 25) then
        vga_r <= "1111";
        vga_g <= "1111";
        vga_b <= "1111";
      end if;
      if (paddleplyr2 > pixelypos - 15) and
        (paddleplyr2 < pixelypos + 15) and
        (pixelxpos > 620) and
        (pixelxpos < 625) then
        vga_r <= "1111";
        vga_g <= "1111";
        vga_b <= "1111";
      end if;
    end if;
  end process;

  -- game play section
  process (VS, rst)                     -- 60Hz clock timing
  begin
    if (rst = '1') then                 -- restart game
      ballx         <= 320;
      bally         <= 280;
      ballxdir      <= 1;
      ballydir      <= 1;
      ballxspd      <= 2;
      ballyspd      <= 2;
      plyr1score    <= 0;
      plyr2score    <= 0;
      plyr1setscore <= 0;
      plyr2setscore <= 0;
      plyr1wins     <= 0;
      plyr2wins     <= 0;
      plyr1serve    <= '0';
      scalebl       <= 1;
      secondsCtr    <= 0;
    elsif (rising_edge(VS)) then
      blip  <= '0';
      blop  <= '0';
      ballx <= ballx + (ballxspd * ballxdir);  -- ball control
      if ballx > 630 then               -- player 2 missed +1pt for player1
        ballxdir   <= -1;
        ballx      <= 560;
        plyr1score <= plyr1score + 1;
        if plyr1score = 10 then
          ballx      <= 320;
          plyr1serve <= '1';
        end if;
        blop <= '1';
      elsif (ballx <= 8) then
        ballxdir   <= 1; ballx <= 80;
        plyr2score <= plyr2score + 1;
        if plyr2score = 10 then
          ballx      <= 320;
          plyr1serve <= '0';
        end if;
        blop <= '1';
      end if;
      if plyr1score >= 11 then
        plyr1setscore <= plyr1setscore + 1;
        plyr1score    <= 0;
        plyr2score    <= 0;
        if plyr1setscore = 2 then
          plyr1wins <= 1;
          ballx     <= 10;
          bally     <= 10;
          ballxdir  <= 0;
          ballydir  <= 0;
          ballxspd  <= 0;
          ballyspd  <= 8;
        end if;
      elsif plyr2score >= 11 then
        plyr2setscore <= plyr2setscore + 1;
        plyr1score    <= 0;
        plyr2score    <= 0;
        if plyr2setscore = 2 then
          plyr2wins <= 1;
          ballx     <= 620;
          bally     <= 10;
          ballxdir  <= 0;
          ballydir  <= 0;
          ballxspd  <= 0;
          ballyspd  <= 8;
        end if;
      end if;
      bally <= bally + (ballyspd * ballydir);
      if bally >= 470 then
        ballydir <= -1;
        blip     <= '1';
      elsif (bally <= 110) then
        ballydir <= 1;
        blip     <= '1';
      end if;
      if (ballx < 30) and (ballx > 20) then    -- Has player 1 hit the ball?
        if (bally > paddlePlyr1 - 24) and (bally < paddlePlyr1 - 16) then
          ballyspd <= 4;
          ballxdir <= 1;
          blip     <= '1';
        elsif (bally > paddlePlyr1 - 16) and (bally < paddlePlyr1 - 8) then
          ballyspd <= 2;
          ballxdir <= 1;
          blip     <= '1';
        elsif (bally > paddlePlyr1 - 8) and (bally < paddlePlyr1) then
          ballyspd <= 0;
          ballxdir <= 1;
          blip     <= '1';
        elsif (bally > paddlePlyr1) and (bally < paddlePlyr1 +8) then
          ballyspd <= 2;
          ballxdir <= 1;
          blip     <= '1';
        elsif (bally > paddlePlyr1 + 8) and (bally < paddlePlyr1 + 16) then
          ballyspd <= 4;
          ballxdir <= 1;
          blip     <= '1';
        end if;
      end if;
      if (ballx < 620) and (ballx > 615) then  -- Has player 2 hit the ball?
        if (bally > paddlePlyr2 - 24) and (bally < paddlePlyr2 - 16) then
          ballyspd <= 4;
          ballxdir <= -1;
          blip     <= '1';
        elsif (bally > paddlePlyr2 - 16) and (bally < paddlePlyr2 - 8) then
          ballyspd <= 2;
          ballxdir <= -1;
          blip     <= '1';
        elsif (bally > paddlePlyr2 - 8) and (bally < paddlePlyr2) then
          ballyspd <= 0;
          ballxdir <= -1;
          blip     <= '1';
        elsif (bally > paddlePlyr2) and (bally < paddlePlyr2 + 8) then
          ballyspd <= 2;
          ballxdir <= -1;
          blip     <= '1';
        elsif (bally > paddlePlyr2 + 8) and (bally < paddlePlyr2 + 16) then
          ballyspd <= 4;
          ballxdir <= -1;
          blip     <= '1';
        end if;


      end if;
      if secondsctr >= 59 then          -- @ 60Hz
        secondsctr <= 0;
        seconds    <= seconds + 1;
      else
        secondsctr <= secondsctr + 1;   -- 1 second period
      -- scaleBL <= (seconds mod 6) + 1;
      end if;

-- player controlled paddles
      paddleplyr1 <= (paddleplyr1 + (to_integer(unsigned(paddlepos1(11 downto 3)))))/2;
      paddleplyr2 <= (paddleplyr2 + (to_integer(unsigned(paddlepos2(11 downto 3)))))/2;
    end if;

  end process;
end architecture RTL;
