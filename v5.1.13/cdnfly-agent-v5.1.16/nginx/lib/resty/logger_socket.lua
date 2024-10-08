LJ$@./nginx/lib/resty/logger_socket.lua      4   L          ! +  L     (   V.   K  "last_error msg   ÷  	 FZ",  -    X-   X- B  X- B    X-  B+   J  9- B-   X-   X-   X 9- - B   X 9- - B   X-   X 9' - &B      X+   J L $ÀÀ/À
unix:connectsetpeernamesettimeoutudp

!connected sock_type udp tcp _write_error timeout host port path ok Eerr  Esock  E Æ  U~-    XL    9  - -   X- - B  X+   J . L  .sslhandshakessl ssl_session sni_host host ssl_verify sock  session err     DÔ-,  -    X
-   X- - '  B+  '  J 1 1  0  - -  X#U"- B     X	-  B     X1 X-   X- - '   B-	   X-
 - B- . XÙ1  -   X+  ' - '   &J L #	ÀÀ
À$&(0À1À%À) retries: 3try to connect to the log server failed after "reconnect to the log server: %previous connection not finished Ð
    ####&'''()))))),connecting debug ngx_log DEBUG connected retry_connect max_retry_times _do_connect _do_handshake exiting ngx_sleep retry_interval err Csock  C   
#¼-   - '  ) - B -   &. 0  - . - -  X- ) N)  B. 0  -   X- -	 ' - ' &BK   À !-	ÀÀ
À.) reached, create a new "log_buffer_data"log buffer reuse limit ( 			



concat log_buffer_data log_buffer_index send_buffer counter max_buffer_reuse new_tab debug ngx_log DEBUG packet  Æ   7Ì,  -  - B    X+   J  9  B    X+   J -   X6 9B- - 6 9B'	 
 '  &		B-  X 9)  -	 B      X+   J L 2À	ÀÀ
À*setkeepaliveudp::log flush:nowupdate_timengx	send						

send_buffer _connect debug ngx_log DEBUG sock_type pool_size ok 6err  6sock  6bytes  6packet 5 B    ê-   )    X +  L  +  L  buffer_size     -ò	-      X 
-     X-  - '  B 1  +  L  +  L  +	ÀÀ
Àflush lock acquiredflushing debug ngx_log DEBUG  r   	'ý-      X-  - '  B 1 K  	ÀÀ
À+flush lock releaseddebug ngx_log DEBUG flushing  ö  
nÔD+   -  B  X	-   X- - '  B+ L - B  X-   X- - ' - B- B+ L 0  -   X- - ' B+  - -  X!U - )   X-	 B-
 B     XX-   X- - '   B-   X- - B- . XÛ- B  X' ' - '   &-  B+   J X
-   X- - '  ' &B- -  !. /	 L 6À	ÀÀ
À5À!7À'(3À4À%À)/À bytes
send  retries: failed after 0try to send log messages to the log server ,resend log messages to the log server: start flushingno need to flush: previous flush not finished Ð		    ""#&&&'''''+++,,,,////22446667778889999;;;<<<<<<<@@@@@AC_flush_lock debug ngx_log DEBUG _need_flush log_buffer_index _flush_unlock retry_send max_retry_times _prepare_stream_buffer _do_flush exiting ngx_sleep retry_interval _write_error buffer_size send_buffer err mbytes &Gerr_msg /  	 "Ê   X1  -   X-    X
-   X- - '  B- BX
-   X- - ' ' &B1 - - - BK  %	ÀÀ
À8ÀÀ9Àhappened before6no need to perform periodic flush: regular flush performing periodic flush


exiting need_periodic_flush debug ngx_log DEBUG _flush timer_at periodic_flush _periodic_flush premature  #     Kà	-   )  - B 1    X-  B+   J K  À8À/À	timer_at _flush need_periodic_flush _write_error ok 
err  
   @ë-   .  - -  < -    . - L ! log_buffer_index log_buffer_data buffer_size msg   í -ÿõy-    B  X+  ' J -   BHß X
-   B X+  ' J . XÓ X-   B X+  ' J )    X-  X+  ' 	 9	-
 B I . Xº
 X
-   B X+  ' J . X® X-   B X+  ' J  X X+  ' J . X X-   B X)   X+  ' J . X X-   B X)   X+  ' J . X} X-   B X)   X+  ' J .	 Xn X-   B X)   X+  ' J .
 X_ X-   B X)   X+  ' J . XP X-   B X)   X+  ' J . XA X-   B X)   X+  ' J . X2 X-   B X)   X+  '  J . X#! X
-   B" X+  '# J . X$ X
-   B" X+  '% J . X& X	-   B X+  '' J . FR-   X-   X-   X+  '( ') &J - -  X+  '* J 1 1 1 1 0  0  1 -   X-   X- - '+ - ', &B1 - - - B- L ÀÀÀ()*+%#$&',	ÀÀ
ÀÀ9À seconds&periodic flush enabled for every +"flush_limit" should be < "drop_limit""path" is required.4no logging server configured. "host"/"port" or  "sni_host" must be a stringsni_host)"ssl_verify" must be a boolean valuessl_verify""ssl" must be a boolean valuebooleansslinvalid "periodic_flush"periodic_flushinvalid "max_buffer_reuse"max_buffer_reuseinvalid "pool_size"pool_sizeinvalid "retry_interval"retry_intervalinvalid "max_retry_times"max_retry_timesinvalid "timeout"timeoutinvalid "drop_limit"drop_limitinvalid "flush_limit"flush_limit'"sock_type" must be "tcp" or "udp"udptcp!"sock_type" must be a stringsock_type"path" must be a string	pathformat"port" out of range 0~%s"port" must be a numbernumber	port"host" must be a stringstring	host user_config must be a table
table 

  !!!!!!!!"""$$%%&&&&&&&&'''))**++++++++,,,..//0000000011133445555555566699::;;;;;;;;<<<>>??@@@@@@@@AAACCDDEEEEEEEEFFFHHIIJJJJJKKKMMNNOOOOOPPPRRSSTTTTTUUUW[[[[[[[[[\]]]]aaaabbbefgijkmooopppqqrrrrqtuuuuxxtype pairs host MAX_PORT port path sock_type flush_limit drop_limit timeout max_retry_times retry_interval pool_size max_buffer_reuse periodic_flush ssl ssl_verify sni_host flushing exiting connecting connected retry_connect retry_send logger_initted debug ngx_log DEBUG need_periodic_flush timer_at _periodic_flush user_config  â â âk ßv  ß ½ 	 ^ð4-    X+  '  J +  -   B X-   B  -   X6 9B- - 6 9B'   &B  - B  X1 -   B-	 B-   X- - ' B)  X"-
  -  X-   B X-
  -  X-   B-	 B X-	 B-   X- - ' ' &B)  -   X- 1    J L ,ÀÀ	ÀÀ
À%;À:À"dropped5logger buffer is full, this log message will be Nginx worker is exiting:log message length: nowupdate_timengxstringnot initialized   !!""$$%%%&&'''&)---./0003logger_initted type tostring debug ngx_log DEBUG is_exiting exiting _write_buffer _flush_buffer buffer_size flush_limit drop_limit last_error msg  _bytes Wmsg_len >err 9 '    ¦-   L  ,logger_initted  ¿ = 3tÑ ®6   9  6 996 996 996 96 9	6
 6 6 6	 9		9		6
 9

6 9*  6 6 ' B  X3  )  ) B+  6 9  X6 99  X6 99)+# X
3   ' ' ' ' &BX6 99' =) * )è, + + , )', ' )  '   )" N)#  B )!  ,"% )&  )'  )( ))d )*
 ,+, )-  +.  3/  30! 31" 32# 33$ 34% 35& 36' 37( 38) 39* 3:+ 3;, 3<. =<-3</ =<3<1 =<0=822  L 
flush initted  	init             	0.03_VERSIONexitingworkerbelow 0.9.3Amessages when Nginx reloads if it works with ngx_lua module @0.9.3 or above. lua-resty-logger-socket will lose some log @We strongly recommend you to update your ngx_lua module to  ngx_lua_version table.newrequire
pcall	CRIT
DEBUG
debugconfigtostring
pairs	type
sleeplogat
timerudptcpsocketngxconcat
tableþÿ             	 	 
                                      ! # # $ % & & & # & ( ( ( , , / 0 1 2 4 5 6 8 : < ? A C C C C E G L M N O P Q S T X |  º Ê è ð û H^isîu$ð(&*,,concat rtcp oudp ltimer_at ingx_log gngx_sleep etype dpairs ctostring bdebug _DEBUG ]CRIT [MAX_PORT Zsucc Vnew_tab  V_M Ois_exiting Nflush_limit /drop_limit .timeout -host ,port  ,ssl +ssl_verify *sni_host )path  )max_buffer_reuse (periodic_flush 'need_periodic_flush  'sock_type &buffer_size %send_buffer $log_buffer_data  log_buffer_index last_error connecting  connected  exiting  retry_connect retry_send max_retry_times retry_interval pool_size flushing logger_initted  counter ssl_session _write_error _do_connect _do_handshake _connect _prepare_stream_buffer _do_flush _need_flush _flush_lock _flush_unlock _flush _periodic_flush _flush_buffer 
_write_buffer 	  