library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity txtScreen is
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
end txtScreen;

architecture RTL of txtScreen is

  component charrom
    port
      (
        address : in  std_logic_vector (10 downto 0);
        clock   : in  std_logic := '1';
        q       : out std_logic_vector (7 downto 0)
        );
  end component;
  component vidmem
    port
      (
        clock     : in  std_logic := '1';
        data      : in  std_logic_vector (7 downto 0);
        rdaddress : in  std_logic_vector (11 downto 0);
        wraddress : in  std_logic_vector (11 downto 0);
        wren      : in  std_logic := '0';
        q         : out std_logic_vector (7 downto 0)
        );
  end component;
  signal char_row_addr : std_logic_vector(10 downto 0);
  signal q_8x12        : std_logic_vector(7 downto 0);
  signal vaddr         : std_logic_vector(11 downto 0);
  signal vdata         : std_logic_vector(7 downto 0);
  signal shifter       : std_logic_vector(7 downto 0);
  signal doubled       : std_logic := '0';

begin

  font8x12_inst : charrom port map (
    address => char_row_addr,
    clock   => pClk,
    q       => q_8x12
    );
  vidmem_inst : vidmem port map (
    clock     => pClk,
    data      => data,
    rdaddress => vAddr,
    wraddress => addr,
    wren      => nWr,
    q         => vData
    );
  vAddr         <= std_logic_vector(to_unsigned(40*((vp-2)/24) + (hp/16), 12));
  char_row_addr <= std_logic_vector(to_unsigned(((conv_integer(vdata(7 downto 0)) -32)*12 + ((vp-2)/2) mod 12), 11));

  process(pClk)
  begin
    shifter(7 downto 0) <= q_8x12(7 downto 0);
    if rising_edge(pClk) then
      if doubled = '0' then
        pix     <= shifter(7- (((hp/2)-1) mod 8));
        doubled <= '1';
      else
        pix     <= shifter(7- (((hp/2)-1) mod 8));
        doubled <= '0';
      end if;
    end if;
  end process;
end RTL;
