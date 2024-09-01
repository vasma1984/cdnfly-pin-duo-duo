/**

 @Name：layuiAdmin Echarts集成
 @Author：star1029
 @Site：http://www.layui.com/admin/
 @License：GPL-2
    
 */


layui.define(function(exports){
  // 获取节点列表
  var admin = layui.admin
  var $ = layui.$

  //折线图
  layui.use(['admin', 'echarts','laydate','carousel'], function(){
    var $ = layui.$
    ,admin = layui.admin
    ,laydate = layui.laydate
    ,element = layui.element
    ,carousel = layui.carousel
    ,element = layui.element
    ,device = layui.device()    
    ,echarts = layui.echarts;

    admin.on('hash(node-monitor-realtime-tab)', function(router){
      console.log(window.node_interval)
      for (i in window.node_interval) {
        clearInterval(window.node_interval[i])
      }
    });

    var node_ajax = admin.req({
      url: '/nodes?limit=0'
      ,type: "get"
      ,loader: false
      ,done: function(res){
        var data = res.data
        for (i in data) {
          selected = ""
          if (i == 0) {
            selected = "selected"
          }
          $(".nodes").append("<option "+selected+" value='"+data[i]['id']+"'>"+data[i]['name']+"</option>");
        }

        $('.nodes').select2({
          placeholder: '选择节点',
          width: 'resolve'
        });

      }
    }); 


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


    function render_chart(id,option) {
        var mychart = echarts.init($("#"+id).children('div')[0], layui.echartsTheme);
        mychart.setOption(option);
        //mychart.showLoading();
        window.onresize = mychart.resize;
        return mychart
    }

    function get_data(type) {
      var range = get_date_range()
      var start = encodeURI(range[0])
      var end = encodeURI(range[1])
      var node = $("select[name='nodes']").val()
      if (!start.match(/[0-9]{4}/)) {
        return
      }

      admin.req({
        url: '/monitor/node/realtime?type='+type+'&start='+start+'&end=' + end + '&node='+node //实际使用请改成服务端真实接口
        ,type: "get"
        ,loader: false
        ,done: function(res){
          //登入成功的提示与跳转
          var data = res.data

          if (type == "bandwidth") {
            $(".nic").empty()
            for (i in data) {
                $bandwidth = $('<div class="layui-carousel layadmin-carousel layadmin-dataview"data-anim="fade"><div carousel-item id="'+i+'"><div><i class="layui-icon layui-icon-loading1 layadmin-loading"></i></div></div></div>')
                $(".nic").append($bandwidth)
            }

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

            for (i in data) {
              var option = {
                title: {
                    text: i,
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
                        var v = value /1000
                        if (v >= 900) {
                          var b = (v/1000).toFixed(2) + " Mbps"
                        } else {
                          var b = (value /1000).toFixed(2) + " Kbps"
                        }

                        show += name + ": " + b + "<br>"
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
                      formatter: function (value, index) {
                        var v = value /1000
                        if (v >= 900) {
                          return (v/1000).toFixed(2) + " Mbps"
                        } else {
                          return (value /1000).toFixed(2) + " Kbps"
                        }
                      }                   
                    }
                },
                series: [{
                    type: 'line',
                    data: []
                }]
              }

              var series = []
              var legend_data = []
              var x = []
              var y = []

              var nic_data = data[i]
              for (j in nic_data) {
                var series_data = {"type":"line"}
                var name = nic_data[j]['name']
                var value = nic_data[j]['data']
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
              option["xAxis"]["data"] = x

              render_chart(i,option) 

            }
          } else if (type == "disk_usage") {
            var num = 0
            $(".disk").empty()
            for (i in data) {
                $bandwidth = $('<div class="layui-carousel layadmin-carousel layadmin-dataview"data-anim="fade"><div carousel-item id="path_'+num+'"><div><i class="layui-icon layui-icon-loading1 layadmin-loading"></i></div></div></div>')
                $(".disk").append($bandwidth)
                num += 1
            }

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

            var num = 0
            for (i in data) {
              var option = {
                title: {
                    text: "分区 "+i,
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
                        show += name + ": " + value.toFixed(1) + " %<br>"
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
                      formatter: '{value} %'
                    }              
                },
                series: [{
                    type: 'line',
                    data: []
                }]
              }

              var series = []
              var legend_data = []
              var x = []
              var y = []

              var nic_data = data[i]
              for (j in nic_data) {
                var series_data = {"type":"line"}
                var name = nic_data[j]['name']
                var value = nic_data[j]['data']
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
              option["xAxis"]["data"] = x

              render_chart("path_"+num,option) 

              num += 1
            }
          } else if (type == "nginx_status") {
            var option = {
              title: {
                  text: "Nginx状态",
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
                  type: 'value'           
              },
              series: [{
                  type: 'line',
                  data: []
              }]
            }

            var series = []
            var legend_data = []
            var x = []
            var y = []

            for (j in data) {
              var series_data = {"type":"line"}
              var name = data[j]['name']
              var value = data[j]['data']
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
            option["xAxis"]["data"] = x

            render_chart("nginx-status",option)          

          } else if (type == "tcp_conn") {
            option = {
                title: {
                    text: 'TCP连接数',
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
                        return formatDate(date,"YY/MM/DD hh:mm") + " <br>" + "连接数: " + value
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
            var x = []
            var y = []
            for (j in data) {
              x.push(data[j][0])
              y.push(data[j][1])
            }

            option["series"][0]["data"] = y
            option["xAxis"]["data"] = x
            render_chart("tcp-conn",option)   

          } else if (type == "sys_load") {
            // cpu
            option = {
                title: {
                    text: 'CPU使用率',
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
                        return formatDate(date,"YY/MM/DD hh:mm") + " <br>" + "使用率: " + value.toFixed(1)+" %"
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
            var x = []
            var y = []
            for (j in data['cpu']) {
              x.push(data['cpu'][j][0])
              y.push(data['cpu'][j][1])
            }

            option["series"][0]["data"] = y
            option["xAxis"]["data"] = x
            render_chart("cpu",option)   

            // mem
            option = {
                title: {
                    text: '内存使用率',
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
                        return formatDate(date,"YY/MM/DD hh:mm") + " <br>" + "使用率: " + value.toFixed(1) + " %"
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
            var x = []
            var y = []
            for (j in data['mem']) {
              x.push(data['mem'][j][0])
              y.push(data['mem'][j][1])
            }

            option["series"][0]["data"] = y
            option["xAxis"]["data"] = x
            render_chart("mem",option)  

            // 负载
            option = {
                title: {
                    text: '系统负载',
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
                        return formatDate(date,"YY/MM/DD hh:mm") + " <br>" + "负载: " + value.toFixed(1)
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
            var x = []
            var y = []
            for (j in data['load']) {
              x.push(data['load'][j][0])
              y.push(data['load'][j][1])
            }

            option["series"][0]["data"] = y
            option["xAxis"]["data"] = x
            render_chart("load",option)  

          }
        }
      })       
    }



    $.when(node_ajax).then(function (argument) {
      interval_update()
    })

    window.node_interval = []
    function  interval_update() {
      // 清理定时
      for (k in window.node_interval) {
        clearInterval(window.node_interval[k])
      }

      window.node_interval = []

      var curr_tab = $(".layui-tab-title .layui-this").text()
      if (curr_tab == "带宽") {
        get_data("bandwidth")        

      } else if (curr_tab == "连接") {
        get_data("nginx_status")
        get_data("tcp_conn")

      } else if (curr_tab == "负载") {
        get_data("sys_load")     

      } else {
        get_data("disk_usage")
      }

    }

    element.on('tab(node-monitor-tab)', function(data){
      // resize
      for (i in window.chart_ins) {
        window.chart_ins[i].resize();
      }

      interval_update()

    });

  });
  
  exports('node_senior', {})
});