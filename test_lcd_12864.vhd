library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

entity test_lcd_12864 is
	port(
		clk_i        : in STD_LOGIC;
		reset_i      : in std_logic;
		
		temper_data_i: in STD_LOGIC_VECTOR( 31 downto 0);
		temper_ok_i  : in std_logic;
		
		data_o       : out STD_LOGIC_VECTOR( 7 downto 0);
		reset_n_o    : out STD_LOGIC;	
		cs_n_o       : out STD_LOGIC;	
		wr_n_o       : out STD_LOGIC;	
		rd_n_o       : out STD_LOGIC;
		a0_o         : out STD_LOGIC
		);
	
end test_lcd_12864;

architecture arch  of test_lcd_12864 is
    component lcd_12864 is
	port(
		clk_i        : in STD_LOGIC;
		reset_i      : in std_logic;

		lcd_ok_o     : out std_logic;
		pos_x_i      : in STD_LOGIC_VECTOR( 3 downto 0);
		pos_y_i      : in STD_LOGIC_VECTOR( 3 downto 0);
		char_index_i : in STD_LOGIC_VECTOR( 3 downto 0);
		char_show_i  : in STD_LOGIC ;
		
		data_o       : out STD_LOGIC_VECTOR( 7 downto 0);
		reset_n_o    : out STD_LOGIC;	
		cs_n_o       : out STD_LOGIC;	
		wr_n_o       : out STD_LOGIC;	
		rd_n_o       : out STD_LOGIC;
		a0_o         : out STD_LOGIC
		);	
    end component;

	TYPE ram_buf_type is array( 0 to 15 ) of std_logic_vector( 3 downto 0);  
	TYPE ram_buf IS ARRAY ( 0 to 7 ) OF ram_buf_type ;
	signal show_ram_data        : ram_buf  ;
	
	type Sys_States is ( sr_sys_init , sr_lcd_show_char , sr_lcd_idle  );
	signal cur_sys_state , next_sys_state : Sys_States;
	
	signal lcd_ok     : std_logic ;
	signal pos_x      : STD_LOGIC_VECTOR( 3 downto 0);
	signal pos_y      : STD_LOGIC_VECTOR( 3 downto 0);
	signal char_index : STD_LOGIC_VECTOR( 3 downto 0);
	signal char_show  : STD_LOGIC ;
	signal show_ok     : std_logic ;

	signal update     : std_logic ;

begin
    U0 : lcd_12864 
	port map (
		clk_i        => clk_i ,
		reset_i      => reset_i ,

		lcd_ok_o     => lcd_ok ,
		pos_x_i      => pos_x ,
		pos_y_i      => pos_y ,
		char_index_i => char_index , 
		char_show_i  => char_show ,
		
		data_o       => data_o    ,   
		reset_n_o    => reset_n_o ,
		cs_n_o       => cs_n_o    ,
		wr_n_o       => wr_n_o    ,
		rd_n_o       => rd_n_o    ,
		a0_o         => a0_o      
	);	
                        
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			cur_sys_state <= sr_sys_init;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    cur_sys_state <= next_sys_state;
		end if;
	end process;
	
	process( cur_sys_state  , lcd_ok , show_ok , update )	
	begin
	    case cur_sys_state is
	    when sr_sys_init => 
	        if (  lcd_ok = '1' ) then
    	        next_sys_state <= sr_lcd_show_char ;
    	    else
    	        next_sys_state <= sr_sys_init ;
    	    end if ;
    	    
        when sr_lcd_show_char =>
            if ( show_ok = '1' ) then
	            next_sys_state <= sr_lcd_idle ; 
	        else
    	        next_sys_state <= sr_lcd_show_char ;
    	    end if ;

	    when sr_lcd_idle =>    
	        if ( update = '1' ) then
	            next_sys_state <= sr_lcd_show_char ;
	        else
	            next_sys_state <= sr_lcd_idle ;
	        end if ;	    
	    end case ;
	end process;
	
	-------------------------------------------------------
	
	show_ok <= '1' when lcd_ok = '1' and pos_x = 15 and pos_y = 7 else '0' ;
	char_show <= '1' when cur_sys_state = sr_lcd_show_char else '0' ;
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			pos_x <= ( others => '0' );
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_sys_state = sr_lcd_idle ) then
		        pos_x <= ( others => '0' );
		    elsif ( cur_sys_state = sr_lcd_show_char and lcd_ok = '1'  ) then
		        if ( pos_x = 15 ) then
        			pos_x <= ( others => '0' );
        		else		        
    			    pos_x <= pos_x + 1;
    			end if;
    		end if ;
		end if;
	end process;

	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			pos_y <= ( others => '0' );
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_sys_state = sr_lcd_idle ) then
		        pos_y <= ( others => '0' );
		    elsif ( cur_sys_state = sr_lcd_show_char and lcd_ok = '1' and pos_x = 15  ) then
		        if ( pos_y = 7 ) then
        			pos_y <= ( others => '0' );
        		else		        
    			    pos_y <= pos_y + 1;
    			end if;
    		end if ;
		end if;
	end process;
	
	char_index <= show_ram_data( conv_integer( pos_y ) ) ( conv_integer( pos_x ) );
	-------------------------------------------------------
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
	        update <= '0' ;
		elsif ( clk_i 'event and clk_i = '1' ) then
	        update <= '0' ;
		    if ( temper_ok_i = '1' ) then
    	        update <= '1' ;
    		end if ;
		end if;
	end process;
	
	
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
	        show_ram_data(0) <= ( x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F" );
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( temper_ok_i = '1' ) then
		        show_ram_data(0)(0)  <= x"F";
		        show_ram_data(0)(1)  <= x"F";
		        show_ram_data(0)(2)  <= x"F";
		        show_ram_data(0)(3)  <= temper_data_i(  3 downto  0 );
		        show_ram_data(0)(4)  <= temper_data_i(  7 downto  4 );
		        show_ram_data(0)(5)  <= temper_data_i( 11 downto  8 );
		        show_ram_data(0)(6)  <= temper_data_i( 15 downto 12 );
		        show_ram_data(0)(7)  <= x"B";
		        show_ram_data(0)(8)  <= temper_data_i( 19 downto 16 );
		        show_ram_data(0)(9)  <= temper_data_i( 23 downto 20 );
		        show_ram_data(0)(10) <= temper_data_i( 27 downto 24 );
		        show_ram_data(0)(11) <= temper_data_i( 31 downto 28 );
		        show_ram_data(0)(12) <= x"F";
		        show_ram_data(0)(13) <= x"F";
		        show_ram_data(0)(14) <= x"F";
		        show_ram_data(0)(15) <= x"F";
    		end if ;
		end if;
	end process;

	show_ram_data(1) <= ( x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F" );
	show_ram_data(2) <= ( x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F" );
	show_ram_data(3) <= ( x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F" );
	show_ram_data(4) <= ( x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F" );
	show_ram_data(5) <= ( x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F" );
	show_ram_data(6) <= ( x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F" );
	show_ram_data(7) <= ( x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F",x"F" );

end ;