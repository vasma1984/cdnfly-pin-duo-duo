LJ@./nginx/on_body_filter.lua�   -� 6   ' B 6 6 96 96 96 996 9	5
 7 6 6 
 B8
  X�6 9:99	
  '  B
 
 ' 	 B6 9>9 BK  limit_bandwidth{node_ip}{client_ip}server_addrremote_addrargtostringvalid_code 403530515514513512504502varsubrestatusERRlogngx
pcallresty.utilrequire			

util *pcall )log 'ERR %ngx_status #re_sub  ngx_var body client_ip node_ip newstr n  err  newstr n  err    