LJ@./nginx/lib/resty/acl.luaÂ  /-    BX!9 9- 9   	    +    
 B  X- 9' B XK  X- )B- 9' BERÝ XK  X- )BK  À ÀÀÀ&[acl apply_rule] acl is not match
allow"[acl apply_rule] acl is match
debugmatch_requestacl_matcheracl_action		

ipairs util logger ngx_exit acl_data  0default_action  0client_ip  0user_agent  0referer  0req_uri  0accept_language  0geoip_country_code  0host  0uri  0req_method  0$ $ $_ !v  !acl_action  acl_matcher     qË*A6   9  9 9 9 ' ' '   X99 X' 6 	 B X:  X-  	 B 9	 X' 6 	 B X:  X-  	 B 9
 X' 6 	 B X:  X-  	 B - 9'	 
 '  '  B9   X-  
 B 9 9	 -
  - 9B
- 9  X X- 9' BK  -  9' B899-        
 	   BK  ÀÀÀÀ	Àacl_datadefault_actionget_data[run] acl is not activeaclgeoip_country_code	hosturireq_uri accept_language: referer:[acl run] user_agent:
debugaccept_languagereferer
table	typeuser_agentreq_methodheadersclient_ipctxngx	
!!!!!!!!!%&&''''+.111133666677778;;;;;;<=@@@@@@@@@@@@@Astring_lower logger ngx_var config apply_rule ngx_ctx oclient_ip nheaders mreq_method luser_agent kreferer jaccept_language ireq_uri <-uri &host %geoip_country_code !acl rule default_action acl_data       r6   ' B 6  ' B6 96 996 996	 6 9
6 96  '
 B3	 3
 5 6 ==	=
2  L runapply_rulematch_request    resty.logger
lowerstring	exitipairs	findreget_headersreqvarngxresty.configresty.utilrequire	

(kmnnopqqutil config ngx_var get_headers re_find ipairs ngx_exit string_lower logger 	apply_rule run   