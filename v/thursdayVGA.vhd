library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity thursdayVGA is
  port(
    MAX10_CLK1_50 : in  std_logic;
    KEY           : in  std_logic_vector (1 downto 0);
    VGA_HS        : out std_logic;
    VGA_VS        : out std_logic;
    VGA_R         : out std_logic_vector (3 downto 0);
    VGA_G         : out std_logic_vector (3 downto 0);
    VGA_B         : out std_logic_vector (3 downto 0)
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



  signal RST       : std_logic;
  signal pixelclk  : std_logic;
  signal Blanking  : std_logic;
  signal hpos      : std_logic_vector(10 downto 0);
  signal vpos      : std_logic_vector(9 downto 0);
  signal pixelxpos : integer range 0 to 639 := 0;
  signal pixelypos : integer range 0 to 479 := 0;

  signal xdotpos  : integer range 0 to 799 := 0;
  signal ydotpos  : integer range 0 to 524 := 0;
  signal ballsize : integer range 0 to 10  := 10;
  signal ballx    : integer range 0 to 639 := 20;
  signal bally    : integer range 0 to 479 := 20;
  signal VS       : std_logic;
  signal HS       : std_logic;


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

  syncgeninst : video_sync_generator port map (
    rst,
    pixelclk,
    blanking,
    HS,
    VS,
    hpos,
    vpos
    );

  process(pixelclk)
  begin
    if ((rst = '1') or (blanking = '0')) then
      vga_r <= "0000";
      vga_g <= "0000";
      vga_b <= "0000";
    elsif (rising_edge(pixelclk)) then

      if (pixelxpos < 215) then
        vga_r <= "1111";
        vga_g <= "0000";
        vga_b <= "0000";
      elsif (pixelxpos > 425) then
        vga_r <= "0000";
        vga_g <= "0000";
        vga_b <= "1111";
      else
        vga_r <= "0000";
        vga_g <= "1111";
        vga_b <= "0000";

      end if;
      if (ballx >= pixelxpos) and (ballx < pixelxpos + ballsize) and
        (bally >= pixelypos) and (bally < pixelypos + ballsize) then
        vga_r <= "1111";
        vga_g <= "1111";
        vga_b <= "1111";
      end if;



    end if;
  end process;
  process (VS)                          -- 60Hz clock timing
  begin
    if (rising_edge(VS)) then
      ballx                     <= ballx + 1;
      if ballx > 639 then ballx <= 0;
      end if;
      bally                     <= bally + 1;
      if bally > 479 then bally <= 0;
      end if;
    end if;
  end process;
end architecture RTL;
