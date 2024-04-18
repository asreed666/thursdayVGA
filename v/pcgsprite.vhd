library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


PACKAGE DW IS -- sprite for ball type objects (10 x 10)
type t_New_Integer_Array is array (integer range <>) of integer;
PROCEDURE SP(signal Xcur,Ycur,Xpos,Ypos:IN INTEGER;variable sprite:IN t_New_Integer_Array(99 downto 0);
signal scale: in integer; SIGNAL DRAW: OUT STD_LOGIC);
END DW;

PACKAGE BODY DW IS
--type t_New_Integer_Array is array (integer range <>) of integer;
PROCEDURE SP(signal Xcur,Ycur,Xpos,Ypos:IN INTEGER;variable sprite:IN t_New_Integer_Array(99 downto 0);
signal scale: in integer; SIGNAL DRAW: OUT STD_LOGIC) IS
BEGIN
    IF(Xpos-Xcur)/scale>=-5 AND (Xpos-xcur)/scale<5 AND (Ypos-Ycur)/scale>=-5 AND (Ypos-ycur)/scale<5 THEN
	  if sprite(5+((xpos - xcur)/scale) + ((5+((ypos - ycur)/scale))*10)) = 1 then 
		DRAW<='1';
	  else
		DRAW<='0';
	  end if;
    ELSE
	 DRAW<='0';
    END IF;
END SP;
END DW;