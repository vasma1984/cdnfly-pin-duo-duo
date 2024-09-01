# {{ stream.version }}
upstream backend_{{stream.id}} {
    {% if stream.balance_way != "rr" %}
        {{stream.balance_way}};
    {% endif %}    

    {%- for b in stream.backend %}
        server {{b.addr}}:{{stream.backend_port}} weight={{b.weight}} {{b.state}};
    {%- endfor %}
}

server {
    {%- for l in stream.listen %}
        listen {{ l.port }} {{ l.protocol }};
        listen [::]:{{ l.port }} {{ l.protocol }};
    {%- endfor %}
        
    proxy_pass backend_{{stream.id}};

    {% if stream.proxy_protocol %}
        proxy_protocol on;
    {% endif %}    

    {% if stream.conn_limit %}
        limit_conn addr {{stream.conn_limit}};
    {% endif %}  

    {% if stream.acl %}
        {%- for r in stream.acl.rule %}
            {{r.action}} {{r.ip}};
        {%- endfor %}
        {{stream.acl.default_action}}  all;
    {% endif %}  

    # 设置uid
    log_by_lua_block {
        ngx.var.uid = "{{stream.uid}}";
        ngx.var.upid = "{{stream.user_package}}";
    }

    {# 四层转发状态 #}
    {% if stream.state != "200" %}
        return 444;
    {% endif %}

}

