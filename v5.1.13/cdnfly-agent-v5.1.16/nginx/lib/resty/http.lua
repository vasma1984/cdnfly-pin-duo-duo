LJ@./nginx/lib/resty/http.luaÄ  5D-   - B    X -  ) - - G  A C  X +   ' -  - B' &J  K   À   coroutinecan't resume a suspendedco_status co select co_resume  « A?-    B  X+  '  2 X3 2  L 2  K  J ÀÀÀÀ could not create coroutineco_create co_status select co_resume func  co    @c-  B  X+   J - 5  =- D ÀÀ'À	sock keepalivengx_socket_tcp setmetatable mt self  sock 
err  
 u   
#l9    X+  ' J  9 D settimeoutnot initialized	sockself  timeout  sock 	 ¦   Kv9    X+  ' J  9 	 
 D settimeoutsnot initialized	sockself  connect_timeout  send_timeout  read_timeout  sock  |  	9    X+  ' J + =  9G C sslhandshakesslnot initialized	sockself  sock  ó 89    X+  ' J -  ) G A= -  ) G A= - 9 B X+  = + =  9G C À#Àconnectkeepalivenumber	port	hostnot initialized	sock




select type self  sock  ù  6 9    X+  ' J 9  X 9G C X 9B  X) ' J X  J K  connection must be closed
closesetkeepalivekeepalivenot initialized	sockself  sock res 	err  	 k   	¶9    X+  ' J  9D getreusedtimesnot initialized	sockself  
sock  b   	À9    X+  ' J  9D 
closenot initialized	sockself  
sock    %Ê   X+  L   X	 X+  L )d  X)È  X+  L + L 	HEADàmethod  code   ­ 
 UÒ)  X+ -   '  ' B  X  X+  '  ' 	 &	J +  '  &J X;:  X6 99 X	 X>X+  '
  &J :  X- :B>X:	 X)»>X)P >:  X: X' >  X:  X
: X:' :&>+  > +  J K  ÀÀ?/0schemaless URIs require a request context: 
https	httpschemevarngxbad uri: , failed to match the uri: jo<^(?:(http[s]?):)?//([^:/\?]+)(?::(\d+))?([^\?]*)\??(.*)





        """"""""#####$$''')ngx_re_match tonumber self  Vuri  Vquery_in_path  Vm 	Merr  Mscheme   Rõþ*9  9   X4  9   X' -   B X' -  B&X X
-  ) ) B X'  &5 - 9 B>9 >>- 8>) -  BH	-  
 B X4 >

 - 	 B	 - 
 BH		 '	 -  B'
 &< FRõF	R	ã'
 <-  D #ÀÀ
ÀÀ(À!ÀÀÀ
: 	path	       method?
table
queryheadersversion    !!!!!!!!"  '')))type ngx_encode_args str_sub str_upper HTTP pairs tostring tbl_concat params  Sversion Qheaders Mquery Ireq "'c &  key values    _ 	value  	 Ì  B«  9  ' B  X,  J -  -  )
 )	 B A -  -  )	 )
 B A -  ) B I À
À*lreceivetonumber str_sub sock  line err   Ô  8¬µ-  9 BU1  9 ' B  X+   J -  ' ' B  XX ::8  X	- 8
B X4 8	>	<- 8
-  B AX- 
 B<- 
 ' ' B  X	Î +  J  ÀÀ#ÀÀÀÀ
^\s*$
tablejo([^:\s]+):\s*(.+)*lreceivenew					

http_headers ngx_re_match type tbl_insert tostring ngx_re_find sock  9headers 5line -err  -m 
#err  #key val  Á 	S¼Ô9)  +     X-   UL   X)   X  X  ! X )  X-  9 ' B  X- +   B-  ) B   X- +  ' B   X  X!   )   X-  9  B  X- +   B-  B  X-   	  X-  9 ) BX-  9 ) B	  X³K  À À  unable to read chunksize*lreceive 		    "#'''((((())****------0011111255555889default_chunk_size sock co_yield tonumber max_chunk_size  Tremaining Rlength Qstr err  str err   ] ;Ó;-  3  2  D %ÀÀÀ :::co_wrap co_yield tonumber sock  default_chunk_size   ª 
u:   X-   -   X)   X'U%-  9   B  X X-   B- -  B  X-  B     X)    X+      X- - ' BXH  XÚXE-   X- -  9 ' B A X:   X- -  9 - B A X0)  U.   -  X- !)   X"-  9  B  X- +   B - - 	 B  X-  B     X)    X+      X- - ' BX	  XÑK  ÀÀ À    *a'Buffer size not specified, bailingclosedreceive 				!"#$$$$%%((()))))**++++-/////////000000223333488:default_chunk_size content_length sock co_yield tonumber ngx_log ngx_ERR max_chunk_size  vstr  err   partial   received 7/length -str err    \<-  3  2  D %ÀÀÀÀÀ ;;;co_wrap co_yield tonumber ngx_log ngx_ERR sock  content_length  default_chunk_size        Ð+   L   þ UÕ9    X+  ' J 4  ) , U B    X+   -  
 B I   X<   Xí-   D Àno body to be readbody_reader	tbl_concat res   reader chunks c chunk err   O    &ò-   - - B A  K     Àco_yield _receive_headers sock  P .ñ-  3  2  D %ÀÀ-À co_wrap co_yield _receive_headers sock   ©  6ø9    X+  ' J  B-  9 5 =BK  À__index  headersno trailerstrailer_readersetmetatable res  reader trailers  · 	 +p-   B  XU B  X
  9  B  X
+   J X
  X+    J   XéX
  X	  9  B  X+   J + +  J #À	sendfunction			
type sock  ,body  ,chunk 	err  partial  ok err  bytes err   ú r-    B  X,  J 	  X  9  '	 B  X,	 
 J - 
   B   J ,À4À*lreceiveÈ		


_receive_status _send_body sock  body  status version  reason  err  ok 	err  	 æ {Û°C-   5  - =B9 9- 9B9  X-  BH	<
	F	R	ý-  B X9  X =9  X*- 9	 )	 )
 B
 X+  ' J 9   X9   X	9   X9	 ' 9 &=X9   X	9  X9	 ' 9 &=X9	 =X9	 =9  X- 9=9	 X9  X' ==-  B- -		 '
  B	 9
 B  X	+	  
 J	 9		 X	
-	
   B	 	 X+  
  J +	 L	 À)À À!À#À
À&À+ÀÀÀ4À100-continueExpect	send
Keep-AliveConnectionversion_USER_AGENTUser-Agent:ssl	portZUnable to generate a useful Host header for a unix domain socket. Please provide one.
unix:	host	HostContent-Lengthstringheadersnew	body	sock__index  ö 		!!"$$'''(((******++.11122222333355666;;;<<<<==>>>>BBsetmetatable DEFAULT_PARAMS http_headers pairs type str_sub _M _format_request ngx_log ngx_DEBUG _send_body self  |params  |sock tbody sheaders pparams_headers o  k v  req Lbytes 	err  ok err  partial   ¦
 öR9  , 99 X-  	 9
B  X
+
  	 J
 X
  X

  	  
   X- 	 B
 	     X+   J - 	 B  X	+	  
 J	 -	 - 9B	 	 X	 X
 X	 X	
 X+ = X	 X+ = - , + - 9	 B  X- - 9
B  X	 X	 X-  B  + X- - 9B  X-	   B  + 9  X-
  B    X+   J X5 =====- ==- =L K  5À,À-À"ÀÀ0À*À.ÀÀ/À2À1À3Àread_trailerstrailer_readerread_bodybody_readerhas_bodyreasonstatus  TrailerContent-LengthchunkedTransfer-Encodingmethodkeepalivekeep-alive
closeConnection	body100-continueExpectheaders	sockÈµæÌ³Æÿ		



  !!!!""""##$''((,-.11111122223333334444455888899::::::;@@@AAAAADDEEEEGHIJKLMMNOOPR_handle_continue _receive_status _receive_headers pcall str_lower _no_body_reader _should_receive_body _chunked_body_reader tonumber _body_reader _trailer_reader _read_body _read_trailers self  params  sock status version  reason  err  _status _version  _err  res_headers \err  \ok 	Sconnection  Sbody_reader Atrailer_reader @err  @has_body ?ok 
encoding  ok 	length  	    ,Ë  9   B  X  J X  9  D K  read_responsesend_requestself  params  res err   ¢  lé, 9   X-  9- 9 B  + =    X- -  BX-  BH< FRý-    D   À    paramsread_responseresponse_read				
		_M self ngx_log ngx_ERR pairs rawget t   k   res err    rk rv   
 ,·Õ'-   BX9   X9 9 X+  ' 2 	  9 
 B  X		 
 2 ERë4  -   BX- 5
 =
5 3 =	B<ERö2  L J J	  ÀÀ&ÀÀÀ!ÀÀ__index   params response_readsend_request<Cannot pipeline request specifying Expect: 100-continue100-continueExpectheaders##$&&ipairs setmetatable _M ngx_log ngx_ERR pairs rawget self  +requests  +  _ params  res err  responses   i params   ¶  Rûÿ.  X4    9   + B  X+   J -   B9
 
 X
=9
 
 X
=	  9
   B
 
 X+   J  X+ 9 X+   9 +    B  X+   J   9  B  X+   J  9B  X+   J =	  9
 B  X- -  B +  J ÀÀÀset_keepalive	bodyread_bodyrequestssl_handshakessl_verify
httpsconnect
query	pathparse_uri				



!!!""###&((())****---unpack ngx_log ngx_ERR self  Suri  Sparams  Sparsed_uri 	Jerr  Jscheme Bhost  Bport  Bpath  Bquery  Bc 5err  5verify ok 
err  res 	err  body err  ok 		err  	  8Ú°  X*    X, -  - B     X+   J   X  X+  L X+   J - B99  X-  -	  B	
 D X  X
-  B X-  	 D X+  L K  "ÀÀÀ/ÀÀÀ.Àchunkedtransfer_encodingcontent_lengthno bodypcall ngx_req_socket ngx_req_get_headers _body_reader tonumber str_lower _chunked_body_reader self  9chunksize  9sock  9ok err  headers length encoding  Ü  nÒ  9  5 -  B=- - 9'	 '
 ' B- 9- 9  X	'	 &=
  9 	 B=- B=D ÀÀÀÀheaders	bodyget_client_body_reader	pathquery_stringis_argsjo%20\surimethod  requestngx_req_get_method ngx_re_gsub ngx_var ngx_req_get_headers self   chunksize    ì  5ÅÜ  X-  - '  BK  6 9=- 9BH
- -	  B	8	  X6 9<FRô9U  B  X-  - 	 BX  X
-  B  X-  -
  BX  XçK  ÀÀ!À$ÀÀÀbody_readerheaderheadersstatusngxno response provided				






		ngx_log ngx_ERR pairs HOP_BY_HOP_HEADERS str_lower ngx_print self  6response  6chunksize  6  k 
v  
reader chunk err  res err   ¨ 7 d Ò ÿ6   ' B 6 996 99996 9	6 9
6 96	 9		6
 9

6 96 96 96 996 996 996 96 96 96 96 96 96 96 96 96 6  6! 6" 6# 6$ 6 % 6!& 6"' 6#( 5$) 3%* 5&+ ''- 9(.&')/ 6* 9*0*9*1*&'*'=',&5'2 =&3'5(4 5)5 3*7 =*6&3*9 =*8&3*; =*:&3*= =*<&3*? =*>&3*A =*@&3*C =*B&3*E =*D&3*F 3+H =+G&3+I 3,J 3-K 3.L 3/M 30N 31O 32P 33Q 34R 35S 36U =6T&36W =6V&36Y =6X&36[ =6Z&36] =6\&36_ =6^&36a =6`&36c =6b&2  L&  proxy_response proxy_request get_client_body_reader request_uri request_pipeline request read_response send_request            parse_uri  
close get_reused_times set_keepalive connect ssl_handshake set_timeouts set_timeout new 	path/methodGETversion³æÌ	³Æÿ  Àÿ HTTP/1.0
³æÌ	³Æÿ HTTP/1.1
__index  ngx_lua_versionconfig (Lua) ngx_lua/_VERSIONlua-resty-http/_USER_AGENT _VERSION	0.10  	content-lengthupgradetransfer-encodingtrailersteproxy-authorizationproxy-authenticatekeep-aliveconnection	type
pcall
pairsipairsselectrawgetunpacktostringtonumbersetmetatableresumestatuscreate
yieldcoroutine
printvarERR
DEBUGlog	gsub
matchreencode_argsinsertconcat
tablesub	find
upper
lowergmatchstringget_methodget_headersreqtcpsocketngxresty.http_headersrequire             	 	 
 
                                            ! " # $ % ) L O R R R R R R R R T T W \ i c s l } v     ³   ½ ¶ Ç À Ï û Ò (2PÍÒîõ -s0ÈvÒËüÕ-ÿO0YR{\~~http_headers |ngx_socket_tcp yngx_req wngx_req_socket vngx_req_get_headers ungx_req_get_method tstr_gmatch rstr_lower pstr_upper nstr_find lstr_sub jtbl_concat htbl_insert fngx_encode_args dngx_re_match angx_re_gsub ^ngx_re_find [ngx_log Yngx_DEBUG Wngx_ERR Ungx_var Sngx_print Qco_yield Oco_create Mco_status Kco_resume Isetmetatable Htonumber Gtostring Funpack Erawget Dselect Cipairs Bpairs Apcall @type ?HOP_BY_HOP_HEADERS >co_wrap =_M <mt 
2HTTP 1DEFAULT_PARAMS 0_should_receive_body _format_request _receive_status _receive_headers _chunked_body_reader _body_reader _no_body_reader _read_body _trailer_reader _read_trailers _send_body _handle_continue   