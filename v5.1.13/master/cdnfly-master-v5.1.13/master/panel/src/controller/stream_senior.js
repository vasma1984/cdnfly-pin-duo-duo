/**

 @Name：layuiAdmin Echarts集成
 @Author：star1029
 @Site：http://www.layui.com/admin/
 @License：GPL-2
    
 */


layui.define(function(exports){
  // 获取端口列表
  var admin = layui.admin
  var $ = layui.$

  admin.on('hash(stream_monitor)', function(router){
    for (i in window.stream_chart_interval) {
      clearInterval(window.stream_chart_interval[i])
    }
  });

  admin.req({
    url: '/streams?limit=0'
    ,type: "get"
    ,loader: false
    ,done: function(res){
      //登入成功的提示与跳转
      var data = res.data
      for (i in data) {
        listen = JSON.parse(data[i]['listen'])
        for (j in listen) {
          port = listen[j]['port']
          protocol = listen[j]['protocol'].toUpperCase()
          port_protocol = port+"/"+protocol
          $(".ports").append("<option value='"+port_protocol+"'>"+port_protocol+"</option>");
        }
        
      }

      $('.ports').select2({
        placeholder: '选择端口',
        allowClear: true,
        width: 'resolve'
      });

    }
  }); 

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

  });


  //折线图
  layui.use(['admin', 'echarts','laydate'], function(){
    var $ = layui.$
    ,admin = layui.admin
    ,laydate = layui.laydate
    ,element = layui.element
    ,echarts = layui.echarts;

    function formatDate(time,format='YY-MM-DD hh:mm:ss'){
        var date = new Date(time);
     
        var year = date.getFullYear(),
            month = date.getMonth()+1,//月份是从0开始的
            day = date.getDate(),
            hour = date.getHours(),
            min = date.getMinutes(),
            sec = date.getSeconds();
        var preArr = Array.apply(null,Array(10)).map(function(elem, index) {
            return '0'+index;
        });//开个长度为10的数组 格式为 ["00", "01", "02", "03", "04", "05", "06", "07", "08", "09"]
     
        var newTime = format.replace(/YY/g,year)
            .replace(/MM/g,preArr[month]||month)
            .replace(/DD/g,preArr[day]||day)
            .replace(/hh/g,preArr[hour]||hour)
            .replace(/mm/g,preArr[min]||min)
            .replace(/ss/g,preArr[sec]||sec);
     
        return newTime;
    };

    function render_date (argument) {
      laydate.render({
        elem: '#date'
        ,type: 'datetime'
        ,range: true
        ,format: 'yyyy-MM-dd (HH:mm)'
        ,value: formatDate(new Date().getTime() - 3600000, 'YY-MM-DD (hh:mm)') + " - " + formatDate(new Date().getTime(), 'YY-MM-DD (hh:mm)')
        ,done: function(value, date, endDate){
        
        }
      });
    }

    function get_date_range(argument) {
      var start = ""
      var end = ""
      if ($("#date").hasClass("active-btn")) {
        var date_range = $("#date").text()
        start = date_range.split(" - ")[0]
        var now = new Date()
        var seconds = now.getSeconds().toString().padStart(2,'0');
        start = start.slice(0,11) + start.slice(12,17) + ":" + seconds
        end = date_range.split(" - ")[1]
        end = end.slice(0,11) + end.slice(12,17) + ":" + seconds

      } else {
        var hours = $(".active-btn").data("hour")
        var now = new Date().getTime()
        start = formatDate(now - hours * 3600 * 1000)
        end = formatDate(now)
      }
      return [start, end]
    }
    render_date()

    $("#date_tip").click(function (argument) {
      $(this).addClass("layui-hide")
      $("#date").removeClass("layui-hide")
      $(".hours").removeClass("active-btn")
      $("#date").addClass("active-btn")
      render_date()
    })

    $(".hours").click(function (argument) {
      $(".hours").removeClass("active-btn")

      $(this).addClass("active-btn")
      $("#date").removeClass("active-btn")
      $("#date").addClass("layui-hide")
      $("#date_tip").removeClass("layui-hide")

      interval_update()
    })

    $("#query").click(function (argument) {
      interval_update()
    })


    function render_chart(id, option) {
        var ele = $('#'+id).children('div')
        var mychart = echarts.init(ele[0], layui.echartsTheme);
        mychart.setOption(option);
        mychart.showLoading();
        window.onresize = mychart.resize;

        return mychart
    }

    window.stream_chart_option = [{
      "id": "stream-bandwidth",
      "option" : {
          title: {
              text: '带宽',
              textStyle: {
                fontSize: 14
              }                
          },
          tooltip: {
              trigger: 'axis',
              formatter: function (params) {
                  params = params[0];
                  name = params[0]
                  date = params[1]
                  value = params[2]
                  var v = value * 8 /1000
                  if (v >= 900) {
                    var b = (v/1000).toFixed(2) + " Mbps"
                  } else {
                    var b = (value * 8 /1000).toFixed(2) + " Kbps"
                  }

                  return formatDate(date,"YY/MM/DD hh:mm") + " <br>" + "带宽: " + b
              },
          },
          xAxis: {
              type: 'category',
              data:[],
              axisLabel: {
                formatter: function (value, index) {
                  return formatDate(value,"MM/DD hh:mm")
                }
              }
          },
          yAxis: {
              type: 'value',     
              axisLabel: {
                formatter: function (value, index) {
                  var v = value * 8 /1000
                  if (v >= 900) {
                    return (v/1000).toFixed(2) + " Mbps"
                  } else {
                    return (value * 8 /1000).toFixed(2) + " Kbps"
                  }
                }                   
              }
          },
          series: [{
              type: 'line',
              data: []
          }]
      }

    },
    {
      "id": "stream-traffic",
      "option" : {
          title: {
              text: '流量',
              textStyle: {
                fontSize: 14
              }                
          },
          tooltip: {
              trigger: 'axis',
              formatter: function (params) {
                  params = params[0];
                  name = params[0]
                  date = params[1]
                  value = params[2]
                  var v = value / 1024
                  if (v >= 921.6) {
                    var t = (v / 1024).toFixed(2) + " MB" 
                  } else {
                    var t = v.toFixed(2) + " KB"
                  }                  
                  return formatDate(date,"YY/MM/DD hh:mm") + " <br>" + "流量: " + t
              },
          },
          xAxis: {
              type: 'category',
              data:[],
              axisLabel: {
                formatter: function (value, index) {
                  return formatDate(value,"MM/DD hh:mm")
                }
              }
          },
          yAxis: {
              type: 'value',     
              axisLabel: {
                formatter: function (value, index) {
                  var v = value / 1024
                  if (v >= 921.6) {
                    return (v / 1024).toFixed(2) + " MB" 
                  } else {
                    return v.toFixed(2) + " KB"
                  }
                }
              }
  
          },
          series: [{
              type: 'line',
              data: []
          }]
      }

    },
    
    ]

    // 定时更新
    function interval_update() {
      // 清理定时
      for (k in window.stream_chart_interval) {
        clearInterval(window.stream_chart_interval[k])
      }

      window.stream_chart_interval = []
      function get_data(index) {
          var type = window.stream_chart_option[index]["id"]
          var range = get_date_range()
          var start = encodeURI(range[0])
          var end = encodeURI(range[1])
          var port = $("select[name='ports']").val()
          if (port) {
            port = port.join(" ")
          } else {
            port = ""
          }          
          admin.req({
            url: '/monitor/stream/realtime?type='+type+'&start='+start+'&end=' + end + '&port='+port //实际使用请改成服务端真实接口
            ,type: "get"
            ,loader: false
            ,done: function(res){
              window.chart_ins[index].hideLoading();
              //登入成功的提示与跳转
              var data = res.data
              var x = []
              var y = []
              var option = window.stream_chart_option[index]["option"]

              //数据为空
              if (data.length == 0) {
                option["xAxis"]["data"] = [0]
                option["series"][0]["data"] = [0]
                window.chart_ins[index].setOption(option,true);                
                return                
              }

              for (j in data) {
                x.push(data[j][0])
                y.push(data[j][1])
              }
              option["series"][0]["data"] = y

              option["xAxis"]["data"] = x
              window.chart_ins[index].setOption(option,true);
            }
          });          
      } 

      // 设置定时，当前tab
      var curr_tab = $(".layui-tab-title .layui-this").text()
      if (curr_tab == "带宽流量") {
        var update_chart = [0,1]
        for (i in update_chart) {
          var p = update_chart[i]
          get_data(p)
        }        

      }

    }

    // 初始化图表
    window.chart_ins = []
    for (i in window.stream_chart_option) {
      window.chart_ins[i] = render_chart(window.stream_chart_option[i]["id"], window.stream_chart_option[i]["option"])
    }

    // 开始首tab间隔更新
    interval_update()

    element.on('tab(stream-monitor-tab)', function(data){
      // resize
      for (i in window.chart_ins) {
        window.chart_ins[i].resize();
      }

      // update
      interval_update()    

      $(".ports-select").removeClass("layui-hide")    

    });

  });
  
  exports('stream_senior', {})
});