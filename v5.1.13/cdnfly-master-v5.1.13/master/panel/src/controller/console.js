/**

 @Name：layuiAdmin 主页控制台
 @Author：贤心
 @Site：http://www.layui.com/admin/
 @License：LPPL
    
 */


layui.define(function(exports){
  
  /*
    下面通过 layui.use 分段加载不同的模块，实现不同区域的同时渲染，从而保证视图的快速呈现
  */
  
  
  //区块轮播切换
  layui.use(['admin', 'carousel'], function(){
    var $ = layui.$
    ,admin = layui.admin
    ,carousel = layui.carousel
    ,element = layui.element
    ,device = layui.device();

    //轮播切换
    $('.layadmin-carousel').each(function(){
      var othis = $(this);
      carousel.render({
        elem: this
        ,width: '100%'
        ,arrow: 'none'
        ,interval: othis.data('interval')
        ,autoplay: othis.data('autoplay') === true
        ,trigger: (device.ios || device.android) ? 'click' : 'hover'
        ,anim: othis.data('anim')
      });
    });
    
    // 问候语
    admin.req({
      url: '/log/login?page=1&limit=2'
      ,type: "get"
      ,contentType:"application/json"
      ,dataType: "json"
      ,done: function(res){
        var last_login = res['data'][1]
        var username = layui.data('layuiAdmin').username
        var sys_name = layui.data('layuiAdmin').sys_name
        var hello
        if (typeof(last_login) == "undefined") {
          hello = username +"您好！欢迎登录"+sys_name+"控制台。"
        } else {
          hello = username +"您好！欢迎回到"+sys_name+"控制台。您上次登录时间"+last_login['create_at2']+"，IP地址"+last_login['ip']+"。"
        }
        $(".hello").text(hello)

      }
    });


    admin.req({
      url: '/admin/overview'
      ,type: "get"
      ,contentType:"application/json"
      ,dataType: "json"
      ,done: function(res){
        $("#domain").text(res.data.domain_count)
        $("#stream_port").text(res.data.stream_port_count)
        $("#cert").text(res.data.cert_count)
        $("#node").text(res.data.node_count)
        $("#curr-nodes").text(res.data.node_count+"个")
        var es_status_code = res.data.es_status.code
        var es_status_msg = res.data.es_status.msg
        var master_msg = res.data.master_msg

        if (es_status_code == 0) {
          $("#es_status").html('<span class="layui-badge layui-bg-green">正常</span>')
          
        } else {
          $("#es_status").html('<span class="layui-badge layui-bg-orange">'+es_status_msg+'</span>')
          
        }

        // 主控状态
        if (master_msg) {
          $("#master_status").html('<button type="button" class="master_err layui-btn layui-btn-warm layui-btn-xs">出错，点击查看详情</button>')
          $(".master_err").click(function (argument) {
            master_msg = "<pre>"+master_msg+"</pre>"
            layer.alert(master_msg)
          })
        } else {
          $("#master_status").html('<span class="layui-badge layui-bg-green">正常</span>')
        }

        var agent_status = res.data.agent_status
        var agent_status_code = agent_status['state']
        var agent_status_msg = agent_status['msg']
        if (typeof(agent_status_code) != "undefined" ) {
          var check_at = agent_status['check_at']
          if (agent_status_code == "failed") {
            $("#agent_status").html('<button lay-href="/system/task/id='+agent_status_msg+'/" type="button" class="layui-btn layui-btn-warm layui-btn-xs">出错，点击查看详情</button><button id="agent-check" type="button" style="margin-left:50px;" class="layui-btn layui-btn-normal layui-btn-xs">立即检查</button>')
          }
          else if (agent_status_code == "pending") {
            $("#agent_status").html('<button lay-href="/system/task/id='+agent_status_msg+'/" type="button" class="layui-btn layui-btn-warm layui-btn-xs">待检查</button><button id="agent-check" type="button" style="margin-left:50px;" class="layui-btn layui-btn-normal layui-btn-xs">立即检查</button>')
          }
          else if (agent_status_code == "process") {
            $("#agent_status").html('<button lay-href="/system/task/id='+agent_status_msg+'/" type="button" class="layui-btn layui-btn-warm layui-btn-xs">检查中</button><button id="agent-check" type="button" style="margin-left:50px;" class="layui-btn layui-btn-normal layui-btn-xs">立即检查</button>')
          } else {
            $("#agent_status").html('<span class="layui-badge layui-bg-green">正常</span><button id="agent-check" type="button" style="margin-left:50px;" class="layui-btn layui-btn-normal layui-btn-xs">立即检查</button>')
          }  

          $("#check_tip").html('Agent状态每五分钟检查一次，上次检查时间<b>'+check_at+'</b>。')

        } else {
          $("#agent_status").html('<span class="layui-badge layui-bg-orange">无节点可查</span><button id="agent-check" type="button" style="margin-left:50px;" class="layui-btn layui-btn-normal layui-btn-xs">立即检查</button>')
          $("#check_tip").text('Agent状态每五分钟检查一次，请等待首次检查。')
        }
        
        $("#agent-check").click(function (argument) {
          admin.req({
            url: '/maintain/agent-check'
            ,type: "post"
            ,dataType: "json"
            ,done: function(res){
              layer.msg('已发送检查指令，请等待一分钟左右完成检查', {
                offset: '15px'
                ,icon: 1
                ,time: 1000
              }, function(){
                layui.index.render();
              });                

            }
          });

        })

      }
    });

    // 获取授权
    admin.req({
      url: '/common/auth'
      ,type: "get"
      ,contentType:"application/json"
      ,dataType: "json"
      ,done: function(res){
        var end_at = res['data']['end_at']
        var nodes = res['data']['nodes']
        if (nodes == -1) {
          $("#nodes").text("不限制")
          $("#end_at").text("不限制") 
        } else {
          $("#nodes").text(nodes+"个")
          $("#end_at").text(end_at)          
        }


      }
    });

    $("#get-auth").click(function (argument) {
      admin.req({
        url: '/common/auth'
        ,type: "post"
        ,contentType:"application/json"
        ,dataType: "json"
        ,done: function(res){
          layer.msg('获取成功', {
            offset: '15px'
            ,icon: 1
            ,time: 1000
          }, function(){
            layui.index.render();
          });                    
        }
      });
    })


  });
  
  exports('console', {})
});