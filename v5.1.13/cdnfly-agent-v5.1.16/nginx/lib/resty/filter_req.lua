LJ!@./nginx/lib/resty/filter_req.lua�  O�(-  5  >> B-  9 + 	 B-  9B 9)�)	�)
�B 9' 4	  B  X�- -	 '
  BK  	 9)
 B	 9
  '	 B    X�- -	 '

   BK  	 9)
')d B  X	�-	 - '  B	K  -	 9		'   '  '  B	K  ������ white_time:! to temp whitelist,site_id: #[add_to_tmp_whitelist] add ip:	infofailed to set keepalive: set_keepalivefailed to set 1
setexselectfailed to connect: unix:/var/run/redis.sockconnectset_timeoutsnewset   - -white					
table_concat dict redis log ERR logger ip  Pwhite_time  Psite_id  Pwhite_key Jred ?ok 4err  4ok "err   �   �G	-  4 > >>B-  9  )	 )
   B- 9' 	  '
  '  ' 6  B' 6  B A	L ��� total_challenges:tostring within_second: site_id: filter:[get_challenge_count] ip:
debug	incrtable_concat dict logger ip  !within_second  !filter_name  !site_id  !challenge_key total_challenges  � `�R-  B !+     X�-   )		 )
 B - 9 ' 	  '
  BX-�- 5 >B- 	 9
 B  X�- 
 ) ) B - 9 '
  '  BX�- 9)
 B - 9 '
  B- 
 9	 - 4 >B)� B- - -
 4 >- >>>B
 A )	 )
 B- 9 '	
 
 ' 6  B' - '  B	  J 
����� �� � name: encrypt_key:tostring[generate_key1] key:set"[generate_key1] self gen rnd:get_rnd_str five_minute:#[generate_key1] from dict rnd:get   	-key
 rnd:[generate_key1] guard:
debug�



ngx_time string_sub logger table_concat dict util ngx_md5 encrypt_key guard  aip  aname  anow ^five_minute \rnd [ip_key )ip_key_v $key 2 � (�o-  B !+     X �-   )		 )
 B - - -
 4 >- >>>B
 A )	 )
 B7  - 9' 	  '
  ' 6  B6  L K  
���� ��
 key:
 rnd:[generate_key2] guard:
debugkey�			ngx_time string_sub ngx_md5 table_concat encrypt_key logger guard  )ip  )name  )now &ten_minute $rnd # � 	 !p|-   9 B 9 B 9B -  9  +	  -
 9

)� ' B
5 =B- 
 96   B A C  ���tostringencryptiv  cbccipher
finalupdatenewresty_md5 aes encode_base64 data  "key  "md5 digest aes_iv_key aes_iv  �  ^�-   9 B 9 B 9B -  9  +	  -
 9

)� ' B
5 =B 9	  D ��decryptiv  cbccipher
finalupdatenewresty_md5 aes data  key  md5 digest aes_iv_key aes_iv  �	 ���<  X�-  9 ' B+ L -  ) B  X�-  9 ' B+ L -  B   X�-  9 ' B+ L -   B  X�-  9 ' B-  -	   ' B	 A   X�-  9 ' B+ L    X�-  9 ' B+ L -  9 ' 	  B-   B     X�-  9 '	 B+ L -   	 B  X�- 	  -
   ' B
 A   X�-  9 '	
 B+ L - 	 B
  X�- 	 B  X�+ L - 	 B - 
 B X�-  9 '	 
 '  '  B-  9 '	 B+ L + L ���'�%��guardret_plain +10 not eq aes_key: guardret_plain:random_num_plain:#second decrypt guardret failed"decode_base64 guardret failedguardret:no guardret%second decrypt random_num failedbrowser_auto$first decrypt random_num failed$decode_base64 random_num failedno random_numcookie guard is nil
debug				

  """""####$$%%%%&&))))**+++++++++,,----..222222222233666666666777777777888899;;logger string_sub decode_base64 aes_decrypt generate_key2 tonumber guardret  �aes_key  �guard  �ip  �random_num �random_num_plain mguardret_plain 49 �  ��-  
     B-	  B		 X	�-	 9	 	'  '   ' B	-	 9		+        B	K  #��� �add_to_tmp_blacklist to temp blacklist:add ip [challenge_verify] filter:	infoget_challenge_count tonumber logger util ip  within_second  max_challenge  block_time  filter_name  site_id  uid  cur_action  cur_challenge  � 	 ��-	       B	-
  B

	 X
�-
 9
 
'  '   ' B
-
 9

+        B
K  #��� �add_to_tmp_blacklist to temp blacklist: per uri add ip #[challenge_verify_uri] filter:	infoget_challenge_count tonumber logger util ip  within_second  max_challenge  block_time  filter_name  req_uri  site_id  uid  cur_action  cur_challenge  � 	 \�-  5  > B-  9 ) )  )x B- 9'  B)   X�+ X�+ L ���'[is_add_white_exceed] total_white:
debug	incr  white-table_concat dict logger aes_key  total_white_key total_white  �  R��-     '  B- 9'  B-       B  X�- 9' B-  B  X�- 9' B-     B+  L - 9' B-  +    '  B  - 9' B-        	 
 B	- - B A - ) )d B-	   B-
 4 >>>D $��(�+�"�)��
��&��browser verify failed.add white exceed 5.add white ip.+[browser_auto] browser verify success.[browser_auto] aes_key:
debugbrowser_auto				




generate_key1 logger browser_verify is_add_white_exceed add_to_tmp_whitelist challenge_verify math_randomseed ngx_time math_random aes_encrypt table_concat ip  Swithin_second  Smax_challenge  Sblock_time  Swhite_time  Sguardret  Sguard  Sfilter_name  Ssite_id  Suid  Scur_action  Saes_key Mrnd  Mrandom C
random_base64  � 	���P6  99-  B- 9  X�- 9'
 B+ L - 
 ) B-	  B		   X	�-	 9		' B	+	 L	 -	   ' B	-  	 B  X�- 9' B-  -   ' B A   X�- 9'	 B+ L - -  ) B A - -  ) )
 B A 
  X�  X�- 9'
 B+ L !*   X�- 9' 6  B' 6  B A+ L    X�- 9' B+ L -   B     X�- 9' B+ L -   ' B-    B  X�- 9' B-   -   ' B A   X�- 9' B+ L -  B  X�- 9' B+ L -  B X�- 9' 6  B'  B+ L + L 
�����$�'�%�� guardret:$[delay_jump_verify] random_num:,[delay_jump_verify] guardret not number#second decrypt guardret failed"first decrypt guardret failed"decode_base64 guardret failedguardret is nil cookie_time:tostring%[delay_jump_verify] lt 4.5s now:9[delay_jump_verify] cookie_time or random_num is nil&second decrypt time_random failed%first decrypt time_random faileddj%decode_base64 time_random failed&[delay_jump_verify] guard is nil.
debugcookie_guardipctxngx��Ȁ		      !!!!!!!""""####$$'((()))))))))))**..////0033334455556699999::::;;<<<<=========>>????@@DDDDDEEEEFFJJJJJJKKKKKKKKKLLOOngx_time ngx_var logger string_sub decode_base64 generate_key1 aes_decrypt generate_key2 tonumber guardret  �aes_key  �guard  �ip  �site_id  �ip �now �guard �time_random �aes_key �rnd  �time_random_plain �random_num tcookie_time mdiff_time baes_key )9rnd  9guardret_plain 5 �  W��-  	   '  B- 9'  B- 
  	    B  X�- 9' B-  B  X�- 9' B-     B+  L - 9' B-  +    '  B  - 9' B-          B	- B-  B- ) )d B-	 -
 4 >>B B-
 4 >>>D $��-�+�"�)�
���&��delay_jump verify failed.add white exceed 5.add white ip.delay_jump verify success.aes_key:
debugdj				




generate_key1 logger delay_jump_verify is_add_white_exceed add_to_tmp_whitelist challenge_verify ngx_time math_randomseed math_random aes_encrypt table_concat ip  Xwithin_second  Xmax_challenge  Xblock_time  Xwhite_time  Xfilter_name  Xsite_id  Xuid  Xcur_action  Xguard  Xguardret  Xaes_key Rrnd  Rnow =random time_random_base64  �  ��-    B5  -  B4  )  ) M
�-
  -  	 	 B8B
O�-  '	 D !����� 66551084932772310849..



math_modf string_len table_insert string_sub table_concat num  num _  map len str_t   i 	 � Z��.  X�   X�-  9 ' B+ L -   B  X�-  9 ' B+ L -  B- 	 B  X�-  9 '
 B+ L - 
  B  X	�-	  9	 	' B	-	  - - 5 >B ' B A		   X	�-	  9	 	' B	+	 L	 -	  B		 	-
  9
 
' 	 '	  B
-
 !	B
) 
 X
�-
  9
 
'
 B
+
 L
 +
 L
 ��/��'�%��� gt 15 rotate_num:need_rotate:!second guard decrypt failed.rotate  12345678 first guard decrypt failed. guard decode_base64 failed.guardret is not a number.guard or guardret is nil.
debug�		$$$$'''''''(((((())))**--logger tonumber num_decrypt decode_base64 aes_decrypt generate_key2 table_concat math_abs guardret  [guard  [aes_key  [rnd  [client_ip  [guardret Mrotate_num Bguard_encrypt ?guard_plain 3need_rotate  �  ,��-  +    '  B- 9'  B-       B  X�- 9' B-     B+ L X�-        	 
 B	+ L K  $��0�"�)�add white ip.aes_key:
debugrotate										

generate_key1 logger rotate_verify add_to_tmp_whitelist challenge_verify client_ip  -within_second  -max_challenge  -block_time  -white_time  -guard  -guardret  -filter_name  -site_id  -uid  -cur_action  -aes_key 'rnd  ' � ���k   X�-  9 ' B+ L   X�-  9 ' B+ L -   B  X�-  9 ' B+ L -   B  X�-  9 ' B-  -	   ' B	 A   X�-  9 ' B+ L - 9 B  X�-  9 '	 B+ L - 	 B	 X�-  9 '	
 B+ L 9  X�+ L 99	9
9 )  X�-  9 ' B+ L , )')  )  6  BX]�9 X�9-  9 ' B+ L 9 X�99 X�99)   X�9
 X�-  9 ' B+ L 9)    X�9 X�-  9 ' B+ L 	  X�99 X �9!!	 X�-  9 ' B+ L !	9!#)
  X�-  9 ' !	9!#B+ L X�+ L X�9 	! X�-  9 ' B+ L ER�K  ��'�%���v.x > (x1 + slider - btn)too fast slide:  (v.x - x1) < (slider - btn)y < 0 or y > page_heightx < 15 or x > page_widthxytimestamp not right.timestampipairsslide move less than 3.page_heightpage_widthsliderbtn	move"slide data_json is not table.
table=slide data json.decode failed or data_json is not table.decode&second slide data decrypt failed.
slide%first slide data decrypt failed.%slide data decode_base64 failed.guard is nil.guardret is nil.
debug!!!!!""""##&''((+,-.01112222336789::::;;;<====>>AAABEEEFIIIIIIIJJJJKKNNNNNNNOOOOPPSSTUXXYYYYYZZZZ[[^^^^^^^________```bbceeeeeffffgg::klogger decode_base64 aes_decrypt generate_key2 json type data  �key  �ip  �guard  �data_encrypt �data_plain �data_json �move zbtn uslider tpage_width spage_height rmove_len qx1 
gt1  gminy fmaxy epre_time d` ` `k ]v  ] �  D��-     '  B- 9'  B-      B  X�- 9' B-  B  X�- 9' B-     B+  L - 9' B-  +    '  B  - 9' B-        	 
 B	- 4 >>D $��2�+�"�)��slide verify failed.add white exceed 5.add white ip.slide verify success.aes_key:
debug
slide		generate_key1 logger slide_verify is_add_white_exceed add_to_tmp_whitelist challenge_verify table_concat ip  Ewithin_second  Emax_challenge  Eblock_time  Ewhite_time  Eguardret  Eguard  Efilter_name  Esite_id  Euid  Ecur_action  Eaes_key ?rnd  ? �  o��9   X�-  9 ' B+ L   X�-  9 ' B+ L -   B  X�-  9 ' B+ L -   B  X�-  9 ' B-  -	   ' B	 A   X�-  9 ' B+ L - 9 B  X�-  9 '	 B+ L - 	 B	 X�-  9 '	
 B+ L 9  X�-  9 '
 B+ L 99	)
  
 X
�)
  
 X
�-
  9
 
' B
+
 L
  

	 X
�-
  9
 
' B
+
 L
 +
 L
 ��'�%���x + y not eq a.#x or y should not less than 0.ayx is nil.x"click data_json is not table.
table=click data json.decode failed or data_json is not table.decode&second click data decrypt failed.
click%first click data decrypt failed.%click data decode_base64 failed.guard is nil.guardret is nil.
debug!!!!!""""##&''(((()),-......////0033344445588logger decode_base64 aes_decrypt generate_key2 json type data  pkey  pip  pguard  pdata_encrypt \data_plain Pdata_json 5x !y 	a  �  D��-     '  B- 9'  B-      B  X�- 9' B-  B  X�- 9' B-     B+  L - 9' B-  +    '  B  - 9' B-        	 
 B	- 4 >>D $��4�+�"�)��click verify failed.add white exceed 5.add white ip.click verify success.aes_key:
debug
click					

generate_key1 logger click_verify is_add_white_exceed add_to_tmp_whitelist challenge_verify table_concat ip  Ewithin_second  Emax_challenge  Eblock_time  Ewhite_time  Eguard  Eguardret  Efilter_name  Esite_id  Euid  Ecur_action  Eaes_key ?rnd  ? �	 	���6-  9 B9898-  B X�:-  B X�:-   B   X�  X�-        	 
 B	+ ' J - 5 >B  X�-  9 B  X�)   X�-        	 
 B	+ ' J 9- - 4 >>>B A - 9	'
  '  '  '  '  B X�-        	 
 B	+ ' J - B-  9B- !B X�-        	 
 B	+ ' J -  9 ) )   B+ +  J ��)�����
��	incrsign expiretime_diffsign wrong sign_cal: sign_arg: time_arg:
 uri:[url_auth_a] key:
debugkeysign use times excceedget   -url-authsign or time arg not found
tabletime_namesign_namesign_use_times !""""""""#############$$%%%%%%%%%%&&&**+++,,,,,----------...22222222444tonumber type challenge_verify table_concat dict ngx_md5 logger ngx_time math_abs ip  �within_second  �max_challenge  �extra  �block_time  �filter_name  �site_id  �uri  �args  �uid  �cur_action  �sign_use_times �sign_arg �time_arg �sign_key %`curr_times 
key Fsign_cal >now  time_diff  � (
���@-  9 B98-  B X�:  X�-        	 
 B	+ ' J - 5 >B  X�-  9 B  X�)   X�-        	 
 B	+ ' J -  ' ' B  X�-        	 
 B	+ '	 J -  :B:::  X�  X�  X�  X�-         
 B	+ '
 J 9- - 5 >>>>>	B A - 9'  '  '  '  '  ! '" # '$ % '& ' B X�-         
 B	+ ' J - B-  9B-	 !B X�-          !
 B	+ ' J -  9 ) )   B+ +  J ��)������
��	incrsign expiretime_diffsign wrong md5hash: sign_arg: sign_cal:
 uid: rand: timestamp:
 uri:[url_auth_b] key:
debug	   - - - -keysign arg nilsign format wrongjo(.*?)\-(.*?)\-(.*?)\-(.*)sign use times excceedget   -url-authsign not found
tablesign_namesign_use_times 

   !"#%%%%%%%%&&&&&&&&&&'''*++++++++++-------------------..//////////00044555666667777777777888<<<<<<<<>>>tonumber type challenge_verify table_concat dict re_match ngx_md5 logger ngx_time math_abs ip  �within_second  �max_challenge  �extra  �block_time  �filter_name  �site_id  �uri  �args  �uid  �cur_action  �sign_use_times �sign_arg �sign_key �curr_times 
m yerr  ytimestamp grand fuid emd5hash dkey Nsign_cal 
Dnow $ time_diff  �  &��9 -  9'  B X�-           	 
 D X� X�-           	 
 D K  �6�7�
TypeB
TypeA[url_auth] mode:
debug	modelogger url_auth_a url_auth_b ip  'within_second  'max_challenge  'extra  'block_time  'filter_name  'site_id  'uri  'args  'uid  'cur_action  'mode % �  O��!+  9 -    ' B  X�-  B X�: X
�- 9' B-     BK  - 9' B-        	 
 B	-  ' ' B  X�::-  ' '	 '
 B	 X�- 5 >>B X�- 5 >>>B X�- 5 >>B L $���"�)����   ?cckey=   ? &cckey=   ?cckey=ijo[&?]?cckey=[^&]+&?jo(.*?)\?(.+)!challenge_302 verify failed."challenge_302 verify success.
debug
tablechallenge_302
cckey		



 generate_key1 type logger add_to_tmp_whitelist challenge_verify re_match re_gsub table_concat ip  Pwithin_second  Pmax_challenge  Pblock_time  Pwhite_time  Pfilter_name  Preq_uri  Pargs  Psite_id  Puid  Pcur_action  Purl_redirect Ncckey Mkey_gen Ireq_uri_m '"req_uri_none_args args args_g  � 	 K��&  X�-  9 ' B+ L   X�-  9 ' B+ L -  B  X�-  9 ' B+ L -  	 B  X�-  9 '	 B- 	 -
   ' B
 A   X�-  9 '	 B+ L    X�-  9 '	 B+ L - 	  B X�-  9 '	 B+ L + L ��'�%��captcha is wrong.data is nil. second capt decrypt failed.captchafirst capt decrypt failed.capt decode_base64 failed.guard is nil.capt is nil.
debug     !!!!""%%logger decode_base64 aes_decrypt generate_key2 string_lower data  Lkey  Lip  Lguard  Lcapt  Lcapt_encrypt 8capt_plain , �  B��-     '  B- 9'  B-       B  X�- 9' B-  B  X�- 9' B-     B+ L - 9' B-  +    '  B  - 9' B-        	 
 B	+ L $��:�+�"�)�captcha verify failed.add white exceed 5.add white ip.captcha verify success.aes_key:
debugcaptcha					

generate_key1 logger captcha_verify is_add_white_exceed add_to_tmp_whitelist challenge_verify ip  Cwithin_second  Cmax_challenge  Cblock_time  Cwhite_time  Cguard  Cguardret  Cfilter_name  Csite_id  Cuid  Ccur_action  Ccapt  Caes_key =rnd  = � > V �� �6   ' B 6  ' B6  ' B6  ' B6  ' B6  ' B6  ' B6 9	9
6 9	96	 9			9		6
 9

6 6 96 96 996 996 96 96 96 96 96 6 96 96 96 9 6 9!6 9"6 96 9#6 9$6 9%" 9 &'#' B 9 ( 6! 9!)!3"* 3#+ 3$, 3%- 3&. 3'/ 3(0 3)1 3*2 3+3 3,4 3-5 3.6 3/7 308 319 32: 33; 34< 35= 36> 37? 38@ 39A 3:B 3;C 5<D 6=E ==E<="F<=#G<=3H<=;I<=,J<=)K<=$L<=%M<=<=<=&N<='O<=*P<=9Q<=8R<=5S<=.T<=1U<2  �L< rotatedelay_jump
clickurl_authchallenge_302challenge_verify_uriaes_decryptaes_encryptgenerate_key2generate_key1challenge_verifybrowser_autocaptcha
slideget_challenge_countadd_to_tmp_whitelistadd_to_tmp_blacklist                            	modfkeyopenrestyget_datainsertlen
lowerget_phaseERRlogdecode_base64encode_base64substringtonumbervar	exitabsrandomrandomseed	math	gsub
matchreconcat
tablemd5	type	time
white
black
guardsharedngxresty.configresty.redisresty.dkjsonresty.aesresty.md5resty.loggerresty.utilrequire                  	 	 	                                                  ! ! " " # # $ $ $ $ $ % % D P m z � � � � � � Vs���-E���Bk������������������������util logger |resty_md5 yaes vjson sredis pconfig mdict jdict_black gdict_white dngx_time btype angx_md5 _table_concat ]re_match Zre_gsub Wmath_randomseed Umath_random Smath_abs Qngx_exit Ongx_var Mtonumber Lstring_sub Jencode_base64 Hdecode_base64 Flog DERR Bget_phase @ngx_exit >string_lower <string_len :table_insert 8encrypt_key 3math_modf 1add_to_tmp_whitelist 0get_challenge_count /generate_key1 .generate_key2 -aes_encrypt ,aes_decrypt +browser_verify *challenge_verify )challenge_verify_uri (is_add_white_exceed 'browser_auto &delay_jump_verify %delay_jump $num_decrypt #rotate_verify "rotate !slide_verify  slide click_verify click url_auth_a url_auth_b url_auth challenge_302 captcha_verify captcha   