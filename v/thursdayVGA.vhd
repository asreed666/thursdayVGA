library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity thursdayVGA is
  port(
    MAX10_CLK1_50 : in  std_logic;
	ADC_CLK_10	  : in std_logic;
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
			CLOCK : in  std_logic                     := 'X'; -- clk
			RESET : in  std_logic                     := 'X'; -- reset
			CH0   : out std_logic_vector(11 downto 0);        -- CH0
			CH1   : out std_logic_vector(11 downto 0);        -- CH1
			CH2   : out std_logic_vector(11 downto 0);        -- CH2
			CH3   : out std_logic_vector(11 downto 0);        -- CH3
			CH4   : out std_logic_vector(11 downto 0);        -- CH4
			CH5   : out std_logic_vector(11 downto 0);        -- CH5
			CH6   : out std_logic_vector(11 downto 0);        -- CH6
			CH7   : out std_logic_vector(11 downto 0)         -- CH7
		);
	end component paddles;

-- sprite for ball
  signal ball : std_logic_vector(99 downto 0) :=
    ('0', '0', '0', '1', '1', '1', '1', '0', '0', '0',
     '0', '0', '1', '1', '1', '1', '1', '1', '0', '0',
     '0', '1', '1', '1', '1', '1', '1', '1', '1', '0',
     '1', '1', '1', '1', '1', '1', '1', '1', '1', '1',
     '1', '1', '1', '1', '0', '0', '1', '1', '1', '1',
     '1', '1', '1', '1', '0', '0', '1', '1', '1', '1',
     '1', '1', '1', '1', '1', '1', '1', '1', '1', '1',
     '0', '1', '1', '1', '1', '1', '1', '1', '1', '0',
     '0', '0', '1', '1', '1', '1', '1', '1', '0', '0',
     '0', '0', '0', '1', '1', '1', '1', '0', '0', '0');
-- sprite for paddle
--  signal paddle : std_logic_vector( 19 downto 0) :=
--	('1', '1',
--	 '1', '1',
--	 '1', '1',
--	 '1', '1',
--	 '1', '1',
--	 '1', '1',
--	 '1', '1',
--	 '1', '1',
--	 '1', '1',
--	 '1', '1');
	

  signal RST       : std_logic;
  signal pixelclk  : std_logic;
  signal Blanking  : std_logic;
  signal hpos      : std_logic_vector(10 downto 0);
  signal vpos      : std_logic_vector(9 downto 0);
  signal pixelxpos : integer range 0 to 639 := 0;
  signal pixelypos : integer range 0 to 479 := 0;
  signal paddlePlyr1 : integer range 0 to 479 := 200;
  signal paddlePlyr2 : integer range 0 to 479 := 200;

  signal xdotpos  : integer range 0 to 799 := 0;
  signal ydotpos  : integer range 0 to 524 := 0;
  signal ballsize : integer range 0 to 10  := 10;
  signal ballx    : integer range 0 to 639 := 20;
  signal bally    : integer range 0 to 479 := 20;
  signal ballxdir : integer range -1 to 1	:= 1;
  signal ballydir : integer range -1 to 1	:= 1;
  signal ballspd  : integer range -10 to 10 := 2;
  signal VS       : std_logic;
  signal HS       : std_logic;
  signal txtaddress: std_logic_vector(11 downto 0);
  signal txtdata  : std_logic_vector(7 downto 0);
  signal wren	  : std_logic;
  signal txtpixel : std_logic;
  signal paddlepos1 : std_logic_vector (11 downto 0);
  signal paddlepos2 : std_logic_vector (11 downto 0);
  signal paddlepos3 : std_logic_vector (11 downto 0);
  signal paddlepos4 : std_logic_vector (11 downto 0);

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
  txtscreenInst : txtscreen port map (
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
			CLOCK => ADC_CLK_10, --      clk.clk
			RESET => rst, --    reset.reset
			CH0   => paddlepos1,   -- readings.CH0
			CH1   => paddlepos2,   --         .CH1
			CH2   => paddlepos3,   --         .CH2
			CH3   => paddlepos4   --         .CH3
--			CH4   => CONNECTED_TO_CH4,   --         .CH4
--			CH5   => CONNECTED_TO_CH5,   --         .CH5
--			CH6   => CONNECTED_TO_CH6,   --         .CH6
--			CH7   => CONNECTED_TO_CH7    --         .CH7
		);
  

  process(pixelclk)
  begin
    if ((rst = '1') or (blanking = '0')) then
      vga_r <= "0000";
      vga_g <= "0000";
      vga_b <= "0000";
    elsif (rising_edge(pixelclk)) then

      if ((pixelypos >= 105) and (pixelypos <= 475)) then
        vga_r <= "0001";
        vga_g <= "0111";
        vga_b <= "0001";
      elsif ((pixelypos >100) and (pixelypos < 105)) or 
			((pixelypos >475) and (pixelypos < 479)) then
        vga_r <= "1111";
        vga_g <= "1111";
        vga_b <= "1111";
      elsif (txtpixel = '1') then
	    vga_r <= "1111";
        vga_g <= "1111";
        vga_b <= "0000";
	  else
        vga_r <= "0000";
        vga_g <= "0000";
        vga_b <= "0000";

      end if;
      if (ballx >= pixelxpos) and (ballx < pixelxpos + ballsize) and
        (bally >= pixelypos) and (bally < pixelypos + ballsize) then
		if (ball((pixelxpos - ballx) + (10 * (pixelypos - bally))-29) =  '1') then
			vga_r <= "1111";
			vga_g <= "1111";
			vga_b <= "1111";
		end if;
      end if;
	  if (paddleplyr1 > pixelypos) and 
		 (paddleplyr1 < pixelypos + 30) and
		 (pixelxpos> 20 ) and
		 (pixelxpos < 25) then
			vga_r <= "1111";
			vga_g <= "1111";
			vga_b <= "1111";
	  end if;
	  if (paddleplyr2 > pixelypos) and 
		 (paddleplyr2 < pixelypos + 30) and
		 (pixelxpos> 620 ) and
		 (pixelxpos < 625) then
			vga_r <= "1111";
			vga_g <= "1111";
			vga_b <= "1111";
	  end if;


    end if;
  end process;
  process (VS)                          -- 60Hz clock timing
  begin
    if (rising_edge(VS)) then
      ballx                     <= ballx + (ballspd * ballxdir); -- ball control
      if ballx >= 639 then ballxdir <= -1;
	  elsif (ballx <= 1) then ballxdir  <= 1; ballx <= 3;
      end if;
      bally                     <= bally + (ballspd * ballydir);
      if bally >= 475 then ballydir <= -1;
	  elsif (bally <= 115) then ballydir  <= 1;
      end if;
	  if (ballx  < 35 ) and (ballx > 25) and
		 (bally > paddlePlyr1 - 20) and
		 (bally < paddlePlyr1 + 20) then
	     ballxdir <= 1;
	  end if;
	  if (ballx  < 625 ) and (ballx > 620) and
		 (bally > paddlePlyr2 - 20) and
		 (bally < paddlePlyr2 + 20) then
	     ballxdir <= -1;
	  end if;
-- player controlled paddles
	  paddleplyr1 <= (paddleplyr1 + (to_integer(unsigned(paddlepos1(11 downto 3)))))/2;
	  paddleplyr2 <= (paddleplyr2 + (to_integer(unsigned(paddlepos2(11 downto 3)))))/2;
	end if;
	
  end process;
end architecture RTL;
