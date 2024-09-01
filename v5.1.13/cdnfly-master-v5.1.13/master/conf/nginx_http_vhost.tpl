# {{ site.version }}

{# http后端 #}
{% if ((site.http_listen and site.backend_protocol == "follow") or site.backend_protocol == "http") and  site.backend_contain_host == false %}
    {%- for port in site.upstream_http_port %}
        upstream http_{{site.id}}_{{port}} {
            {% if site.balance_way != "rr" %}
                {{site.balance_way}};
            {% endif %}    

            {%- for b in site.backend %}
                server {{ b.addr }}:{{ port }} weight={{ b.weight }} {{ b.state }} max_fails=0 fail_timeout=10;
            {%- endfor %}     

            {% if site.ups_keepalive  %}
                keepalive {{site.ups_keepalive_conn}};
                keepalive_timeout {{site.ups_keepalive_timeout}};
            {% endif %}    

        }
    {%- endfor %}  

{% endif %}

{# https后端 #}
{% if ((site.https_listen and site.backend_protocol == "follow") or site.backend_protocol == "https") and site.backend_contain_host == false %}
    {%- for port in site.upstream_https_port %}
        upstream https_{{site.id}}_{{port}} {
            {% if site.balance_way != "rr" %}
                {{site.balance_way}};
            {% endif %}   

            {%- for b in site.backend %}
                server {{ b.addr }}:{{ port }} weight={{ b.weight }} {{ b.state }} max_fails=0 fail_timeout=10;
            {%- endfor %}   

            {% if site.ups_keepalive  %}
                keepalive {{site.ups_keepalive_conn}};
                keepalive_timeout {{site.ups_keepalive_timeout}};
            {% endif %}    

        }
    {%- endfor %}  

{% endif %}

{# map变量，用于proxy_no_cache #}
{%- for m in site.maps %}
    map {{ m.check_var }} {{ m.make_var }} {
        default       "0";
        "~*{{m.match_str}}" 1;
    }
{%- endfor %}

{# 健康检查 #}
{% if site.health_check.enable and site.backend|length > 1 %}
    # health_check: {{site.health_check_json}}
{% endif %}

{# server公共部分 #}

{% set server %}
    {# 设置变量 #}
    set $site_id {{ site.id }};
    set $rule_name {{ site.cc_default_rule }};
    set $acl "{{ site.acl }}";
    set $uid "{{ site.uid }}";
    set $upid "{{ site.user_package }}";
    set $block_proxy "{{ site.block_proxy }}";
    set $force_ssl_enable "{{ site.https_listen.force_ssl_enable }}";
    set $force_ssl_port "{{ site.https_listen.force_ssl_port }}";

    {# http监听 #}
    {% if site.http_listen %}
        {%- for p in site.http_listen.ports %}
            listen {{p}};
            listen [::]:{{p}};
        {%- endfor %}
    {% endif %}

    {# https监听 #}
    {% if site.https_listen %}
            {%- for p in site.https_listen.ports %}
                {% if site.https_listen.http2 %}
                    listen {{p}} ssl http2;
                    listen [::]:{{p}} ssl http2;
                {% else %}
                    listen {{p}} ssl;
                    listen [::]:{{p}} ssl;
                {% endif %}

            {%- endfor %}


        {# hsts #}
        {% if site.https_listen.hsts %}
            more_set_headers "Strict-Transport-Security: max-age=31536000;"; 
        {% endif %}

        {# ocsp_stapling #}
        {% if site.https_listen.ocsp_stapling %}
            ssl_stapling on;
            ssl_stapling_verify on;
            resolver 8.8.8.8;
        {% endif %}

        {# ssl_protocols #}
        ssl_protocols {{ site.https_listen.ssl_protocols }};

        {# ssl_ciphers #}
        ssl_ciphers {{ site.https_listen.ssl_ciphers }};

        {# ssl_prefer_server_ciphers #}
        ssl_prefer_server_ciphers {{ site.https_listen.ssl_prefer_server_ciphers }};

        ssl_session_cache shared:SSL:10m;

        {# 证书 #}
        ssl_certificate /usr/local/openresty/nginx/conf/vhost/cert/{{ site.https_listen.cert }}.cert;
        ssl_certificate_key /usr/local/openresty/nginx/conf/vhost/cert/{{ site.https_listen.cert }}.key;

    {% endif %}

    proxy_ssl_protocols {{ site.proxy_ssl_protocols }};

    {# .well-known不执行rewite阶段 #}
    {% if site.acme_proxy_to_orgin == 0 %}
        if ($request_uri ~ "/.well-known/acme-challenge/") {
            rewrite (.*) $1 break;
        }
    {% endif %}

    {#POST请求限制#}
    client_max_body_size {{site.post_size_limit}}m;

    {# 回源协议 #}
    {% if site.backend_protocol == "follow" %}

        {# 当开启回源端口映射时，直接使用$server_port #}
        {% if site.backend_port_mapping %}
            set $backend_port $server_port;
        {% else %}
            set $backend_port "{{site.backend_http_port}}";
            if ($scheme = "https") {
                set $backend_port "{{site.backend_https_port}}";
            }            
        {% endif %} 

        {% if not site.backend_contain_host %}
            set $upstream ${scheme}://${scheme}_{{site.id}}_${backend_port};
        {% else %}
            set $upstream ${scheme}://{{site.backend[0]['addr']}}:${backend_port};
        {% endif %}

    {% else %}
        {% if not site.backend_contain_host %}
            {% if site.backend_protocol == "http" %}
                set $upstream {{site.backend_protocol}}://{{site.backend_protocol}}_{{site.id}}_{{ site.backend_http_port }};
            {% else %}
                set $upstream {{site.backend_protocol}}://{{site.backend_protocol}}_{{site.id}}_{{ site.backend_https_port }};
            {% endif %}
        {% else %}
            {% if site.backend_protocol == "http" %}
                set $upstream http://{{site.backend[0]['addr']}}:{{ site.backend_http_port }};
            {% else %}
                set $upstream https://{{site.backend[0]['addr']}}:{{ site.backend_https_port }};
            {% endif %}

        {% endif %}

    {% endif %} 


    {# 跨域资源请求 #}
    {% if site.cors.enable %}
        {% if site.cors.allow_origin == "*" %}
            set $cors_origin "*";
        {% else %}
            set $cors_origin "";
            if ($http_origin ~* "^{{site.cors.allow_origin}}$") {
                    set $cors_origin $http_origin;
            }

        {% endif %}    

        more_set_headers "Access-Control-Allow-Origin: $cors_origin";
        more_set_headers "Access-Control-Allow-Methods: {{site.cors.allow_methods}}";
        more_set_headers "Access-Control-Allow-Headers: {{site.cors.allow_headers}}";
        more_set_headers "Access-Control-Expose-Headers: {{site.cors.expose_headers}}";

        {% if site.cors.allow_credentials  %}
            more_set_headers "Access-Control-Allow-Credentials: true";
        {% endif %}    

    {% endif %}

    {# 代理公共部分 #}
    {% set proxy %}
        {# 网站状态 #}
        {% if site.state != "200" %}
            content_by_lua_block {
                ngx.exit({{site.state}})
            }
        {% else %}
            {# 是否开启range #}
            {% if site.range %}
                slice             1m;
                proxy_set_header  Range $slice_range;
            {% endif %}

            proxy_pass $upstream;
            proxy_set_header Host {{site.backend_host}};
            
            proxy_ssl_server_name on;
            proxy_ssl_name {{site.backend_host}};
            proxy_set_header        X-Real-IP       $remote_addr;
            proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header        X-Forwarded-Proto $thescheme;
            proxy_connect_timeout {{site.proxy_timeout}}s;
            proxy_send_timeout {{site.proxy_timeout}}s;
            proxy_read_timeout {{site.proxy_timeout}}s; 

            {# websocket开启 #}
            {% if site.websocket_enable %}
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection $connection_upgrade;

            {% else %}
                {% if site.ups_keepalive  %}
                    proxy_http_version 1.1;
                    proxy_set_header Connection "";
                {% else %}
                    proxy_http_version {{site.proxy_http_version}};

                {% endif %}

                proxy_hide_header Upgrade;

            {% endif %}

            {# 请求头 #}
            {%- for h in site.req_header %}
                proxy_set_header "{{h.name}}" "{{h.value}}";
            {% endfor %}

            {# 跨域资源请求 #}
            {% if site.cors.enable %}
                if ($request_method = 'OPTIONS') {
                    more_set_headers "Access-Control-Allow-Origin: $cors_origin";
                    more_set_headers "Access-Control-Allow-Methods: {{site.cors.allow_methods}}";
                    more_set_headers "Access-Control-Allow-Headers: {{site.cors.allow_headers}}";
                    more_set_headers "Access-Control-Expose-Headers: {{site.cors.expose_headers}}";

                    {% if site.cors.allow_credentials  %}
                        more_set_headers "Access-Control-Allow-Credentials: true";
                    {% endif %}   

                    more_set_headers "Access-Control-Max-Age: {{site.cors.max_age}}";
                    more_set_headers "Content-Type: text/plain; charset=utf-8";
                    more_set_headers "Content-Length: 0";
                    return 204;
                }
            {% endif %}

        {% endif %}


    
    {% endset %}

    {# LE证书申请用 #}
    {% if site.acme_proxy_to_orgin == 0 %}
        location ~* /.well-known/acme-challenge/ {
            proxy_bind off;
            proxy_pass http://localhost:80;
        }
    {% endif %}

    {# 系统错误页 #}
    location ~ ^/(403|502|504|512|513|514|515).err {
        rewrite ^(.*).err $1.html break;
        header_filter_by_lua_block { ngx.header.content_length = nil }
        access_by_lua_block {  }
        root /usr/local/openresty/nginx/conf/vhost/;
        internal;
    }

    {# 旋转图片 #}
    location ~ /guard/__rotate_img__/ {
        internal;
        more_set_headers "Content-Type: image/jpeg";
        rewrite /guard/__rotate_img__/(.*) /$1 break;
        root /opt/cdnfly/nginx/conf/rotate/;
    }

    {# 代理缓存 #}
    {%- for c in site.cache %}
        location ~* {{ c.uri }} {
            {# 公共部分 #}
            {{ proxy }}

            proxy_cache cache;

            {# proxy_ignore_headers #}
            {% if c.proxy_ignore_headers %}
                proxy_ignore_headers {{ c.proxy_ignore_headers }};
            {% endif %}

            {# 是否忽略参数 #}
            {% if c.ignore_arg %}
                {% set cache_key = '$scheme://$host$uri' %}
            {% else %}
                {% set cache_key = '$scheme://$host$request_uri' %}
            {% endif %}

            {# range相关 #}
            {% if site.range or c.range %}
                proxy_cache_key {{cache_key}}~$slice_range;
                proxy_cache_valid 200 206 {{ c.expire }}{{ c.unit }};


            {% else %}
                proxy_cache_key {{cache_key}};
                proxy_cache_valid 200 {{ c.expire }}{{ c.unit }};

            {% endif %}

            {% if not site.range and c.range %}
                slice             1m;
                proxy_set_header  Range $slice_range;
            {% endif %}


            {# 不缓存设置 #}
            {% if c.no_cache %}
                proxy_no_cache {{ c.no_cache }};
                proxy_cache_bypass {{ c.no_cache }};
            {% endif %}  

            more_set_headers "X-Cache-Status: $upstream_cache_status";
            proxy_buffering on;
        }
    {%- endfor %}    

    {# 默认代理 #}
    location / {
        {{ proxy }}  
        more_set_headers "X-Cache-Status: MISS";

    }

    {# 防盗链 #}
    {% if site.hotlink.enable %}
        valid_referers {% if site.hotlink.allow_empty %} none {% endif %} server_names blocked {{ site.hotlink.domain }};
        if ($invalid_referer) {
            return 403;
        }
    {% endif %}

    {# 响应头 #}
    {%- for h in site.resp_header %}
        more_set_headers "{{h.name}}: {{h.value}}";
    {% endfor %}

    {% if site.page_404 or site.page_50x %}
        proxy_intercept_errors on;
    {% endif %}

    {# 404错误页 #}
    {% if site.page_404 %}
        error_page 404             /{{ site.id }}.404.html;
        location = /{{ site.id }}.404.html {
            access_by_lua_block {  }
            root /usr/local/openresty/nginx/conf/vhost/error-page;
            internal;
        }  
    {% endif %}

    {# 50x错误页 #}
    {% if site.page_50x %}
        error_page 500 502 503 504 /{{ site.id }}.50x.html;
        location = /{{ site.id }}.50x.html {
            access_by_lua_block {  }
            root /usr/local/openresty/nginx/conf/vhost/error-page;
            internal;
        }  
    {% endif %}


    {# url转向 #}
    {% if site.url_rewrite %}
        set $host_port $host:$server_port;
    {% endif %}

    {%- for r in site.url_rewrite %}
        if ($host_port ~ "^{{r.host}}") {
            rewrite {{ r.match }} {{ r.redirect }} {{r.code}};
        }
    {% endfor %}

    {# gzip开启 #}
    {% if site.gzip_enable %}
        gzip on;
        gzip_types {{ site.gzip_types }};
    {% endif %}

{% endset %}

{# 不包含通配符的server #}
{% if site.non_wildcard_domain != "" %}
server {
    server_name {{site.non_wildcard_domain}};
    set $server_name2 $host;
    {{ server }}
}
{% endif %}

{# 域名为通配符的server #}
{%- for h in site.wildcard_domain %}
    server {
        server_name {{h}};
        set $server_name2 $server_name;
        {{ server }}
    }
{% endfor %}



