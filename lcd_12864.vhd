library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

entity lcd_12864 is
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
	
end lcd_12864;

architecture arch  of lcd_12864 is
    
    CONSTANT INIT_CMD_NUM   : integer := 14 ;
    CONSTANT ROM_CHAR_NUM   : integer := 15 ;
    
	TYPE init_buf_type is array( 0 to INIT_CMD_NUM ) of std_logic_vector( 7 downto 0);  --
	signal soft_init_data   : init_buf_type  ;
	signal soft_init_addr   : integer range 0 to INIT_CMD_NUM ;
    
	type Chip_States is ( sr_lcd_idle , sr_lcd_busy );
	signal cur_lcd_state , next_lcd_state : Chip_States;
	
	type Sys_States is ( sr_sys_init , sr_hw_rst , sr_soft_init , sr_sys_idle , sr_set_addr, sr_sys_show );
	signal cur_sys_state , next_sys_state : Sys_States;

	TYPE rom_buf_type is array( 0 to 7 ) of std_logic_vector( 7 downto 0);  -- 8*8 bit
	TYPE rom_buf IS ARRAY ( 0 to ROM_CHAR_NUM ) OF rom_buf_type ;
	signal rom_data        : rom_buf  ;
	
	signal init_counter    : integer range 0 to 15 ;
	signal reset_counter   : integer range 0 to 15 ;
	
	signal lcd_enable      : std_logic ; 
	signal data_out        : std_logic_vector( 7 downto 0 );	
	signal chip_ok         : std_logic ; 
	signal is_cmd          : std_logic ;

	signal init_ok         : std_logic ; 
	signal hw_reset_ok     : std_logic ; 
	signal soft_init_ok     : std_logic ; 
	--signal page_clr_ok     : std_logic ; 
	--signal full_clr_ok     : std_logic ; 
	
	signal show_ok     : std_logic ; 	
	signal data_index : integer range 0 to ROM_CHAR_NUM ;
	signal data_addr : integer range 0 to 7 ;

	signal column_addr   : std_logic_vector( 7 downto 0 );
	signal page_addr     : std_logic_vector( 3 downto 0 );
	signal set_addr_step : integer range 0 to 2 ;
	signal set_addr_ok     : std_logic ; 	
	
begin
    ---------------------------------------------------------------------------------
    -- 
    rom_data(0)   <= ( x"00",x"7E",x"ff",x"81",x"FF",x"7E",x"00",x"00" ) ; -- 0
    rom_data(1)   <= ( x"00",x"82",x"82",x"FF",x"FF",x"80",x"80",x"00" ) ; -- 1
    rom_data(2)   <= ( x"00",x"C6",x"E7",x"B1",x"9F",x"8E",x"00",x"00" ) ; -- 2
    rom_data(3)   <= ( x"00",x"42",x"89",x"89",x"FF",x"76",x"00",x"00" ) ; -- 3
    rom_data(4)   <= ( X"00",x"30",x"2C",x"A2",x"FF",x"FF",x"A0",x"00" ) ; -- 4
    rom_data(5)   <= ( x"00",x"4F",x"87",x"85",x"FD",x"79",x"00",x"00" ) ; -- 5
    rom_data(6)   <= ( x"00",x"7C",x"FE",x"8B",x"F9",x"71",x"00",x"00" ) ; -- 6
    rom_data(7)   <= ( x"00",x"03",x"01",x"F1",x"FF",x"0F",x"00",x"00" ) ; -- 7
    rom_data(8)   <= ( x"00",x"76",x"FF",x"89",x"FF",x"76",x"00",x"00" ) ; -- 8
    rom_data(9)   <= ( x"00",x"8E",x"9F",x"D1",x"7F",x"3E",x"00",x"00" ) ; -- 9
    rom_data(10)  <= ( x"00",x"00",x"CC",x"CC",x"00",x"00",x"00",x"00" ) ; -- :
    rom_data(11)  <= ( x"00",x"00",x"C0",x"C0",x"00",x"00",x"00",x"00" ) ; -- .
    rom_data(12)  <= ( x"00",x"10",x"10",x"10",x"10",x"10",x"00",x"00" ) ; -- -
    rom_data(13)  <= ( x"00",x"10",x"10",x"7c",x"10",x"10",x"00",x"00" ) ; -- +
    rom_data(14)  <= ( x"00",x"80",x"f0",x"7c",x"1f",x"03",x"00",x"00" ) ; -- /
    rom_data(15)  <= ( x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00" ) ; --      
    
	soft_init_data(0) <= x"e2" ;  --/*软复位*/
	soft_init_data(1) <= x"2c" ;  --/*升压步聚1*/
	soft_init_data(2) <= x"2e" ;  --/*升压步聚2*/
	soft_init_data(3) <= x"2f" ;  --/*升压步聚3*/
	soft_init_data(4) <= x"24" ;  --/*粗调对比度，可设置范围0x20～0x27*/
	soft_init_data(5) <= x"81" ;  --/*微调对比度*/
	soft_init_data(6) <= x"1C" ;
    soft_init_data(7) <= x"a2" ;  --/*1/9偏压比（bias）*/
	-- soft_init_data(7) <= x"a3" ;  --/*1/7偏压比（bias）*/
	soft_init_data(8) <= x"c8" ;  --/*行扫描顺序：从上到下*/
	soft_init_data(9) <= x"a0" ;  --/*列扫描顺序：从左到右*/
	soft_init_data(10) <= x"40" ; --/*显示起始行：第一行开始*/
	soft_init_data(11) <= x"b0" ; --/*写入起始页：第一页开始*/
	soft_init_data(12) <= x"10" ; --/*写入起始列：第一列开始*/
	soft_init_data(13) <= x"00" ; --/*写入起始列：第一列开始*/
	soft_init_data(14) <= x"af" ; --/*开显示*/
    
    lcd_ok_o <= '1' when cur_sys_state = sr_sys_idle else '0' ;
    
    ------------------------------------------------------------------------
    -- LCD interface FSM
    --
    chip_ok    <= '1' when cur_lcd_state = sr_lcd_busy else '0' ;    
		
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			cur_lcd_state <= sr_lcd_idle;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    cur_lcd_state <= next_lcd_state;
		end if;
	end process;
	
	process( cur_lcd_state , lcd_enable )	
	begin
	    case cur_lcd_state is
	    when sr_lcd_idle => 
	        if ( lcd_enable = '1' ) then
    	        next_lcd_state <= sr_lcd_busy ;
	        else
    	        next_lcd_state <= sr_lcd_idle ;
	        end if ;
        when sr_lcd_busy =>
	        next_lcd_state <= sr_lcd_idle ;     	            
	    end case ;
	end process;
	
    -- LCD interface output
    --
    rd_n_o         <= '1' ;
    reset_n_o      <= '0' when cur_sys_state = sr_hw_rst else '1' ;

	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			cs_n_o <= '1';
		elsif ( clk_i 'event and clk_i = '1' ) then
  			cs_n_o <= '1';
		    if ( cur_lcd_state = sr_lcd_idle and lcd_enable = '1' ) then
    			cs_n_o <= '0';
    		end if ;
		end if;
	end process;
	
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			a0_o <= '1';
		elsif ( clk_i 'event and clk_i = '1' ) then
  			a0_o <= '1';
		    if ( cur_lcd_state = sr_lcd_idle and lcd_enable = '1'  and is_cmd = '1' ) then
    			a0_o <= '0';
    		end if ;
		end if;
	end process;
	
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			wr_n_o <= '1';
		elsif ( clk_i 'event and clk_i = '1' ) then
  			wr_n_o <= '1';
		    if ( cur_lcd_state = sr_lcd_idle and lcd_enable = '1'  ) then
    			wr_n_o <= '0';
    		end if ;
		end if;
	end process;
	
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			data_o <= ( others => '0' );
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_lcd_state = sr_lcd_idle and lcd_enable = '1'  ) then
    			data_o <= data_out;
    		end if ;
		end if;
	end process;
	
    ------------------------------------------------------------------------
    -- System Control FSM
    --    
	init_ok       <= '1' when init_counter = 15 else '0' ;
	
	hw_reset_ok   <= '1' when reset_counter = 15 else '0' ;
	
    soft_init_ok  <= '1' when ( is_cmd = '1' and chip_ok = '1' and soft_init_addr = 14 )
                         else '0' ;

    show_ok       <= '1' when ( is_cmd = '0' and chip_ok = '1' and data_addr = 7 )
                         else '0' ;
                       
    set_addr_ok   <= '1' when ( is_cmd = '1' and chip_ok = '1' and set_addr_step = 2 )
                         else '0' ;  
    
    -- page_clr_ok <= '1' when ( is_cmd = '0' and chip_ok = '1' and column_addr = 131 )
    --                    else '0' ;  
                       
                       
    -- full_clr_ok <= '1' when  page_addr = "0111" 
    --                   else '0' ;  
                        
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			cur_sys_state <= sr_sys_init;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    cur_sys_state <= next_sys_state;
		end if;
	end process;
	
	process( cur_sys_state  , init_ok , hw_reset_ok , soft_init_ok ,
	         char_show_i , set_addr_ok , show_ok )	
	begin
	    case cur_sys_state is
	    when sr_sys_init => 
	        if (  init_ok = '1' ) then
    	        next_sys_state <= sr_hw_rst ;
    	    else
    	        next_sys_state <= sr_sys_init ;
    	    end if ;
    	    
        when sr_hw_rst =>
            if ( hw_reset_ok = '1' ) then
	            next_sys_state <= sr_soft_init ; 
	        else
    	        next_sys_state <= sr_hw_rst ;
    	    end if ;
	                	            
        when sr_soft_init =>
            if ( soft_init_ok = '1' ) then
	            next_sys_state <= sr_sys_idle ;
            else
	            next_sys_state <= sr_soft_init ;
	        end if ;
	        
        when sr_set_addr =>
            if( set_addr_ok = '1' ) then 
                next_sys_state <= sr_sys_show ;
	        else
	            next_sys_state <= sr_set_addr ;
	        end if ;
	        
	    when sr_sys_show  =>        	            
            if ( show_ok = '1' ) then
	            next_sys_state <= sr_sys_idle ;
            else
	            next_sys_state <= sr_sys_show ;
	        end if ;
	    when sr_sys_idle =>    
	        if ( char_show_i = '1' ) then
	            next_sys_state <= sr_set_addr ;
	        else
	            next_sys_state <= sr_sys_idle ;
	        end if ;	    
	    end case ;
	end process;
    ---------------------------------------------------------------
    --
    -- Init and HW reset delay counter
    --	
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			init_counter <= 0 ;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_sys_state = sr_sys_init ) then
                init_counter <= init_counter + 1 ;
    		end if ;
		end if;
	end process;

	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			reset_counter <= 0 ;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_sys_state = sr_hw_rst ) then
                reset_counter <= reset_counter + 1 ;
    		end if ;
		end if;
	end process;
    ---------------------------------------------------------------
    --
    -- Latch user input
    --
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			column_addr <= ( others => '0' ) ;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_sys_state = sr_sys_idle and char_show_i = '1' ) then
                column_addr <= '0'&pos_x_i&"000" ;
    		end if ;
		end if;
	end process;

	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			page_addr <= ( others => '0' ) ;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_sys_state = sr_sys_idle and char_show_i = '1' ) then
                page_addr <= pos_y_i ;
    		end if ;
		end if;
	end process;

	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			data_index <= 0 ;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_sys_state = sr_sys_idle and char_show_i = '1' ) then
                data_index <= conv_integer(char_index_i) ;
    		end if ;
		end if;
	end process;
    ---------------------------------------------------------------	
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			soft_init_addr <= 0 ;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_sys_state = sr_hw_rst ) then
  			    soft_init_addr <= 0 ;
		    elsif ( cur_sys_state = sr_soft_init ) then
		        if ( chip_ok = '1' and soft_init_addr < INIT_CMD_NUM ) then
  			        soft_init_addr <= soft_init_addr + 1 ;
    		    end if;
    		end if ;
		end if;
	end process;
	
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			set_addr_step <= 0 ;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_sys_state = sr_sys_idle ) then
  			    set_addr_step <= 0 ;
		    elsif ( cur_sys_state = sr_set_addr ) then
		        if ( chip_ok = '1' and set_addr_step < 2 ) then
  			        set_addr_step <= set_addr_step + 1 ;
    		    end if;
    		end if ;
		end if;
	end process;
	
	
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			data_addr <= 0 ;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_sys_state = sr_sys_idle ) then
  			    data_addr <= 0 ;
		    elsif ( cur_sys_state = sr_sys_show ) then
		        if ( chip_ok = '1' ) then
		            if ( data_addr < 7 ) then
  			            data_addr <= data_addr + 1 ;
  			        else
    			        data_addr <= 0 ;
    		        end if;
    		    end if;
    		end if ;
		end if;
	end process;
	
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			is_cmd <= '0' ;
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( cur_sys_state = sr_soft_init or
		         cur_sys_state = sr_set_addr ) then
  			    is_cmd <= '1' ;
		    elsif ( cur_sys_state = sr_sys_show ) then
  			    is_cmd <= '0' ;
    		end if ;
		end if;
	end process;
		
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			lcd_enable <= '0';
		elsif ( clk_i 'event and clk_i = '1' ) then
		    if ( chip_ok = '1' ) then
    			lcd_enable <= '0';
		    elsif (  cur_sys_state = sr_soft_init or 
		             cur_sys_state = sr_set_addr or
		             cur_sys_state = sr_sys_show ) then
    			lcd_enable <= '1';
    		end if ;
		end if;
	end process;
	
	process(clk_i , reset_i) 
	begin
		if ( reset_i = '1'  ) then
			data_out <= ( others => '0' );
		elsif ( clk_i 'event and clk_i = '1' ) then
		    case cur_sys_state is
		        when sr_soft_init =>
  			        data_out <= soft_init_data( soft_init_addr );        -- lcd_cmd;
  			    when sr_set_addr =>
  			        case set_addr_step is
  			            when 0 => data_out <= "0001"& column_addr( 7 downto 4 );
  			            when 1 => data_out <= "0000"& column_addr( 3 downto 0 );
   			            when 2 => data_out <= "1011"& page_addr ;
                        when others => null;
                    end case ;
		        when sr_sys_show =>
  			        data_out <=  rom_data(data_index)( data_addr ); -- data_buf( data_addr );
		        when others => NULL ;
    		end case ;
		end if;
	end process;

end ;