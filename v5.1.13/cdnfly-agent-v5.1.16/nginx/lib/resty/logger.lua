LJ@./nginx/lib/resty/logger.lua� 	 56    BH
�6  B X�-  9 B< FR�-   D ��encode
table	type
pairsjson concat t    k 
v  
 �  K�#-  9 6 99  X�' - B-  9' B99- 5	 >>>> B- B X�K  - 9
B  X�- 95 -	 	 9		' B	9		9		=	-	 	 9		' B	9		9		=	B  X�- -
 '  BK  - 9 B  X�- -
 '  BK  K  ����� ���failed to log message: -failed to initialize the logger_socket: 	port periodic_flushdrop_limit��@flush_limit� sock_typeudppool_sized	host	initinitted
  [-] [cdnfly] [ ] [ ] [ ]  
log_levellogopenrestyget_datanilrequest_idctxngxremote_addr     !#ngx_var get_headers config concat get_phase logger_socket log ERR msg  Lremote_ip Irequest_id Fheaders Alevel :data 3ok err  bytes 	err  	 � !i;
-     9   ' B 9  9    X�- 4 G  ?  B-   9 ' B99- 9 X�  X� X�-  BK  �	��
�remote_addrdebug_ip
debuglog_levellogopenrestyget_data����
config to_string ngx_var send_log level msg debug_ip remote_ip 	 � =G-     9   ' B 9  9    X�  X�- 4 G  ?  B-  BK  �	�
�	info
debuglog_levellogopenrestyget_data����config to_string send_log level msg 	 � ?O-     9   ' B 9  9    X�  X�  X�- 4 G  ?  B-  BK  �	�
�warning	info
debuglog_levellogopenrestyget_data����config to_string send_log level msg  � AW-     9   ' B 9  9    X�  X�  X�  X�- 4 G  ?  B-  BK  �	�
�
errorwarning	info
debuglog_levellogopenrestyget_data����config to_string send_log level msg  �   #� d6   ' B 6  ' B6 96 96 96 96 9	9
6  '	 B6 93	 3
 3 3 3 3 5 ====2  �L 
errorwarning	info
debug        get_phaseresty.dkjsonget_headersreqvarconcat
tableERRlogngxresty.configresty.logger_socketrequire			


9EMU]^_`abcclogger_socket  config log ERR concat ngx_var get_headers json get_phase to_string send_log debug 
info 	warning error   