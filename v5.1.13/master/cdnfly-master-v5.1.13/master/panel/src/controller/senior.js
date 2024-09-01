/**

 @Name：layuiAdmin Echarts集成
 @Author：star1029
 @Site：http://www.layui.com/admin/
 @License：GPL-2
    
 */


layui.define(function(exports){
  // 获取域名列表
  var admin = layui.admin
  var $ = layui.$

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
      $(".time-period").css("width","450px")
      render_date()
    })

    $(".hours").click(function (argument) {
      $(".hours").removeClass("active-btn")

      $(this).addClass("active-btn")
      $("#date").removeClass("active-btn")
      $("#date").addClass("layui-hide")
      $("#date_tip").removeClass("layui-hide")
      $(".time-period").css("width","300px")

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

    window.chart_option = [{
      "id": "bandwidth",
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
                  if (v >= 900000) {
                    var b = (v/1000/1000).toFixed(2) + " Gbps"
                  }
                  else if (v >= 900) {
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
                  if (v >= 900000) {
                    return (v/1000/1000).toFixed(2) + " Gbps"
                  }
                   else if (v >= 900) {
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
      "id": "traffic",
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
                  if (v >= 943718.4) {
                    var t = (v/1024/1024).toFixed(2) + " GB"
                  }
                  else if (v >= 921.6) {
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
                  if (v >= 943718.4) {
                    return (v/1024/1024).toFixed(2) + " GB"
                  }
                  else if (v >= 921.6) {
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
    {
      "id": "req",
      "option" : {
          title: {
              text: '访问次数',
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
                  return formatDate(date,"YY/MM/DD hh:mm") + " <br>" + "访问次数: " + value
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
          },
          series: [{
              type: 'line',
              data: []
          }]
      }

    },
    {
      "id": "qps",
      "option" : {
          title: {
              text: 'QPS',
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
                  return formatDate(date,"YY/MM/DD hh:mm") + " <br>" + "QPS: " + value.toFixed(1)
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
          },
          series: [{
              type: 'line',
              data: []
          }]
      }

    },
    {
      "id": "req-cache-status",
      "option" : {
          title: {
              text: '请求命中率',
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
                  return formatDate(date,"YY/MM/DD hh:mm") + " <br>" + "请求命中率: " + value + "%"
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
                formatter: '{value} %'
              }
          },
          series: [{
              type: 'line',
              data: []
          }]
      }

    },
    {
      "id": "byte-cache-status",
      "option" : {
          title: {
              text: '字节命中率',
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
                  return formatDate(date,"YY/MM/DD hh:mm") + " <br>" + "字节命中率: " + value + "%"
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
                formatter: '{value} %'
              }
          },
          series: [{
              type: 'line',
              data: []
          }]
      }
    },
    {
      "id": "status-4xx",
      "option" : {
          title: {
              text: '4xx状态码',
              textStyle: {
                fontSize: 14
              }                
          },
          legend: {
            show: true,     
            data: []     
          },          
          tooltip: {
              trigger: 'axis',
              formatter: function (params) {
                var date = formatDate(params[0][1],"YY/MM/DD hh:mm") + " <br>" 
                var show = date
                for (i in params) {
                  var name = params[i][0]
                  var value = params[i][2]
                  show += name + ": " + value + "次<br>"
                }
                return show
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
                formatter: '{value} 次'
              }              
          },
          series: [{
              type: 'line',
              data: []
          }]
      }
    },
    {
      "id": "status-5xx",
      "option" : {
          title: {
              text: '5xx状态码',
              textStyle: {
                fontSize: 14
              }  
          },
          legend: {
            show: true,     
            data: []     
          },            
          tooltip: {
              trigger: 'axis',
              formatter: function (params) {
                var date = formatDate(params[0][1],"YY/MM/DD hh:mm") + " <br>" 
                var show = date
                for (i in params) {
                  var name = params[i][0]
                  var value = params[i][2]
                  show += name + ": " + value + "次<br>"
                }
                return show
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
                formatter: '{value} 次'
              }              
          },
          series: [{
              type: 'line',
              data: []
          }]
      }
    },
    {
      "id": "backend-bandwidth",
      "option" : {
          title: {
              text: '回源带宽',
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
                  if (v >= 900000) {
                    var b = (v/1000/1000).toFixed(2) + " Gbps"
                  }
                  else if (v >= 921.6) {
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
                  if (v >= 900000) {
                    return (v/1000/1000).toFixed(2) + " Gbps"
                  }

                  else if (v >= 921.6) {
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
      "id": "backend-traffic",
      "option" : {
          title: {
              text: '回源流量',
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
                  if (v >= 943718.4) {
                    return (v/1024/1024).toFixed(2) + " GB"
                  }
                  else if (v >= 921.6) {
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
                  if (v >= 943718.4) {
                    return (v/1024/1024).toFixed(2) + " GB"
                  }
                  else if (v >= 921.6) {
                    return (v / 1024).toFixed(2) + " MB" 
                  } else {
                    return v.toFixed(2) + " KB"
                  }
                }
              },  
          },
          series: [{
              type: 'line',
              data: []
          }]
      }

    },  
    {
      "id": "backend-resp-time",
      "option" : {
          title: {
              text: '回源耗时',
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
                  return formatDate(date,"YY/MM/DD hh:mm") + " <br>" + "平均耗时: " + value.toFixed(3) + " 秒"
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
                  return value + " 秒"
                }                   
              }
  
          },
          series: [{
              type: 'line',
              data: []
          }]
      }

    }

    ]

    // 定时更新
    function interval_update() {

      function get_data(index) {
          var type = window.chart_option[index]["id"]
          var range = get_date_range()
          var start = encodeURI(range[0])
          var end = encodeURI(range[1])
          var domain = $("input[name='domains']").val()
          var server_port = $("input[name='server_port']").val()
 
          if (!start.match(/[0-9]{4}/)) {
            return
          }
                
          admin.req({
            url: '/monitor/site/realtime?type='+type+'&start='+start+'&end=' + end + '&domain='+domain +'&server_port=' + server_port //实际使用请改成服务端真实接口
            ,type: "get"
            ,loader: false
            ,done: function(res){
              window.chart_ins[index].hideLoading();
              //登入成功的提示与跳转
              var data = res.data
              var x = []
              var y = []
              var option = window.chart_option[index]["option"]

              //数据为空
              if (data.length == 0) {
                option["xAxis"]["data"] = [0]
                option["series"][0]["data"] = [0]
                window.chart_ins[index].setOption(option,true);                
                return                
              }

              if (type == "status-4xx" || type == "status-5xx") {
                var series = []
                var legend_data = []
                for (j in data) {
                  var series_data = {"type":"line"}
                  var name = data[j]['name']
                  var value = data[j]['value']
                  var y = []

                  for (k in value) {
                    // 拿到x轴时间戳
                    if (j == 0) {
                      var timestamp = value[k][0]
                      x.push(timestamp)
                    }
                    // y轴
                    y.push(value[k][1])
                  }
                  series_data["name"] = name
                  series_data["data"] = y
                  series.push(series_data)
                  legend_data.push({"name":name})
                }

                option["series"] = series
                option["legend"]["data"] = legend_data

              }
              else {
                for (j in data) {
                  x.push(data[j][0])
                  y.push(data[j][1])
                }
                option["series"][0]["data"] = y
              }
              option["xAxis"]["data"] = x
              window.chart_ins[index].setOption(option,true);
            }
          });          
      } 

      // 设置定时，当前tab
      var curr_tab = $(".layui-tab-title .layui-this").text()
      if (curr_tab == "基础数据") {
        var update_chart = [0,1,2,3]
      } else if (curr_tab == "质量监控") {
        var update_chart = [4,5,6,7]
      } else {
        var update_chart = [8,9,10]
      }

      for (i in update_chart) {
        var p = update_chart[i]
        get_data(p) 
      }

    }

    // 初始化图表
    window.chart_ins = []
    for (i in window.chart_option) {
      window.chart_ins[i] = render_chart(window.chart_option[i]["id"], window.chart_option[i]["option"])
    }

    // 开始首tab间隔更新
    interval_update()

    element.on('tab(monitor-tab)', function(data){
      // resize
      for (i in window.chart_ins) {
        window.chart_ins[i].resize();
      }

      // update
      interval_update()

    });

  });
  
  exports('senior', {})
});