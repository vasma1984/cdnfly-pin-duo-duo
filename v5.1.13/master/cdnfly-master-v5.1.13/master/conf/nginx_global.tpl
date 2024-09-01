load_module "modules/ngx_http_geoip2_module.so";
daemon on;
error_log  {{config.logs_dir}}/error.log  error ;
pid logs/nginx.pid;
thread_pool default threads=32 max_queue=65536;

worker_processes  {{config.worker_processes}};
worker_cpu_affinity auto;
worker_rlimit_nofile {{config.worker_rlimit_nofile}};
worker_shutdown_timeout {{config.worker_shutdown_timeout}};
pcre_jit on;

events {
    accept_mutex off;
    use epoll;
    worker_connections  {{config.worker_connections}};
    worker_aio_requests 32;
}

http {
    autoindex off;
    
    # gzip
    gzip off;
    gzip_comp_level {{config.http.gzip_comp_level}};
    gzip_http_version {{config.http.gzip_http_version}};
    gzip_min_length {{config.http.gzip_min_length}};
    gzip_proxied off;
    gzip_vary {{config.http.gzip_vary}};

    # log
    log_format  access  '__NODE_ID__\t$uid\t$upid\t$time_local\t$remote_addr\t$request_method\t$scheme\t$server_name2\t$server_port\t$request_uri\t$server_protocol\t$status\t$bytes_sent\t$http_referer\t$http_user_agent\t$sent_http_content_type\t$up_resp_time\t$upstream_cache_status\t$up_bytes_received'; 
    access_log {{config.logs_dir}}/access.log access;

    map $upstream_response_time $up_resp_time {
        "" "0";
        default $upstream_response_time;
    }

    map $upstream_bytes_received $up_bytes_received {
        "" "0";
        default $upstream_bytes_received;
    }

    map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      close;
    }

    map $http_x_forwarded_proto $thescheme {
        default $scheme;
        https https;
    }

    geo $dollar {
        default "$";
    }

    # proxy
    proxy_buffer_size 64k;
    proxy_buffers   32 32k;
    proxy_busy_buffers_size 128k;
    proxy_cache_lock on;

    proxy_buffering {{config.http.proxy_buffering}};
    proxy_request_buffering {{config.http.proxy_request_buffering}};
    proxy_cache_methods {{config.http.proxy_cache_methods}};
    proxy_cache_valid 301      1h;
    proxy_cache_valid any      1m;
    proxy_http_version {{config.http.proxy_http_version}};
    proxy_max_temp_file_size {{config.http.proxy_max_temp_file_size}};
    proxy_next_upstream {{config.http.proxy_next_upstream}}; 
    proxy_cache_path  {{config.http.proxy_cache_dir}} levels=1:2 keys_zone=cache:{{config.http.proxy_cache_keys_zone_size}} inactive=24h  max_size={{config.http.proxy_cache_max_size}};

    {% if config.http.server_addr_outgoing == "1" %}
        proxy_bind $server_addr transparent;
    {% endif %}

    # other
    underscores_in_headers on;
    more_set_headers "Server: {{config.http.server}}";
    client_max_body_size {{config.http.client_max_body_size}};
    default_type {{config.http.default_type}};
    keepalive_requests {{config.http.keepalive_requests}};
    keepalive_timeout {{config.http.keepalive_timeout}};
    log_not_found {{config.http.log_not_found}};
    resolver {{config.resolver}} valid=600 ipv6=off;
    resolver_timeout {{config.resolver_timeout}};
    server_names_hash_max_size {{config.http.server_names_hash_max_size}};
    server_names_hash_bucket_size {{config.http.server_names_hash_bucket_size}};
    server_tokens {{config.http.server_tokens}};
    large_client_header_buffers {{config.http.large_client_header_buffers}};

    # ssl
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4:!DH:!DHE;
    ssl_prefer_server_ciphers on;

    # cc
    lua_socket_log_errors off;
    lua_package_path "/opt/cdnfly/nginx/lib/?.lua;;";
    lua_shared_dict guard 150m;
    lua_shared_dict dict_captcha 60m;
    lua_shared_dict log 50m;
    lua_shared_dict white 50m;
    lua_shared_dict black 50m;
    lua_shared_dict healthcheck 100m;
    init_by_lua_file "/opt/cdnfly/nginx/on_init.lua";
    init_worker_by_lua_file "/opt/cdnfly/nginx/on_init_worker.lua";
    access_by_lua_file "/opt/cdnfly/nginx/on_access.lua";
    body_filter_by_lua_file "/opt/cdnfly/nginx/on_body_filter.lua";
    log_by_lua_file  "/opt/cdnfly/nginx/on_log.lua";
    geoip2 /opt/geoip/GeoLite2-Country.mmdb {
        $geoip_country_code default=US country iso_code;
        $geoip_country_name country names en;
    }

    # error page
    error_page 403             /403.err;
    error_page 502             /502.err;
    error_page 504             /504.err;
    error_page 512             /512.err;
    error_page 513             /513.err;
    error_page 514             /514.err;
    error_page 515             /515.err;

    server {
        merge_slashes off;
        set $rule_name 6;
        set $uid 0;
        set $upid 0;
        set $server_name2 000.com;
        listen unix:/var/run/nginx.sock;
        location /nginx-status {
            stub_status on;
        }

        access_log off;
    }
    
    include listen_80.conf;
    include listen_other.conf;
    include vhost/*.conf;
}

stream {
    log_format basic '__NODE_ID__\t$uid\t$upid\t$server_port/$protocol\t$remote_addr\t$time_local\t$status\t$bytes_sent\t$bytes_received\t$session_time';
    access_log {{config.logs_dir}}/stream.log basic;
    limit_conn_zone $binary_remote_addr zone=addr:100m;
    resolver {{config.resolver}} valid=600 ipv6=off;
    resolver_timeout {{config.resolver_timeout}};
    proxy_connect_timeout {{config.stream.proxy_connect_timeout}};
    proxy_timeout {{config.stream.proxy_timeout}};

    lua_add_variable $uid;
    lua_add_variable $upid;

    include stream/*.conf;
}


