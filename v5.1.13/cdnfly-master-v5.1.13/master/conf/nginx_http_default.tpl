server {
    proxy_bind off;
    error_page 530  /host_not_found.html;

    {# 如果site表有监听80端口，那么就标记一下，以便让config_task不做处理 #}
    {% if site.http_80_site_listen %}
        # http_80_site_listen
    {% endif %}

    set $rule_name 6;
    set $uid 0;
    set $upid 0;
    set $site_id 0;
    set $server_name2 ${host}-no-config;
    server_name localhost;

    {# http监听 #}
    {% if site.http_port %}
        {%- for p in site.http_port %}
            listen {{p}} default_server;
            listen [::]:{{p}} default_server;
        {%- endfor %}
    {% endif %}

    ssl_protocols                TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;

    {# https监听 #}
    {% if site.https_port %}
        {%- for p in site.https_port %}
            listen {{p}} default_server ssl;
            listen [::]:{{p}} default_server ssl;
        {%- endfor %}

        {# 证书 #}
        ssl_certificate /opt/cdnfly/agent/conf/default.cert;
        ssl_certificate_key /opt/cdnfly/agent/conf/default.key;

    {% endif %}

    {# 不防御 #}
    if ($request_uri ~ "/.well-known/acme-challenge/") {
        rewrite (.*) $1 break;
    }

    {# .well-known #}
    location /.well-known/acme-challenge/ {
        proxy_pass http://MASTER_IP:88;
    }

    {# 旋转图片 #}
    location ~ /guard/__rotate_img__/ {
        internal;
        more_set_headers "Content-Type: image/jpeg";
        rewrite /guard/__rotate_img__/(.*) /$1 break;
        root /opt/cdnfly/nginx/conf/rotate/;
    }

    more_set_headers "Content-Type: text/html;charset=utf-8";
    location / {
        
        if ($host ~ "\.[0-9]+$") {
            echo_status 200;
            echo_location /access_ip_not_allow.html;
        }

        set $ret_530 "1";
        if ($uri ~ "/_guard/|favicon.ico") {
            set $ret_530 "0";
        }

        if ($host !~ "\.[0-9]+$") {
            set $ret_530 "${ret_530}2";
        }
        
        if ($ret_530 = "12") {
            return 530;
        }
    }

    location /access_ip_not_allow.html {
        header_filter_by_lua_block { ngx.header.content_length = nil }
        internal;
        root /usr/local/openresty/nginx/conf/vhost/;
    }


    location /host_not_found.html {
        header_filter_by_lua_block { ngx.header.content_length = nil }
        internal;
        root /usr/local/openresty/nginx/conf/vhost/;
    }

}