/**

 @Name：layuiAdmin Echarts集成
 @Author：star1029
 @Site：http://www.layui.com/admin/
 @License：GPL-2
    
 */


layui.define(function(exports){
  //区块轮播切换
  layui.use(['admin', 'carousel'], function(){
    var $ = layui.$
    ,admin = layui.admin
    ,carousel = layui.carousel
    ,element = layui.element
    ,table = layui.table
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
    ,table = layui.table
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

    function format_bandwidth(value) {
      var v = value * 8 /1000
      if (v >= 900000) {
        return (v/1000/1000).toFixed(2) + " Mbps"
      } else if (v >= 921.6) {
        return (v/1000).toFixed(2) + " Mbps"
      } else {
        return (value * 8 /1000).toFixed(2) + " Kbps"
      }
    }

    function render_date (argument) {
      laydate.render({
        elem: '#date'
        ,type: 'date'
        ,range: true
        ,format: 'yyyy-MM-dd'
        ,value: formatDate(new Date().getTime(), 'YY-MM-DD') + " - " + formatDate(new Date().getTime()+3600*1000*24, 'YY-MM-DD')
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
        end = date_range.split(" - ")[1]

      } else {
        var day = $(".active-btn").data("day")
        if (day == "today") {
          start = formatDate(new Date().getTime(), 'YY-MM-DD')
          end = formatDate(new Date().getTime()+3600*1000*24, 'YY-MM-DD')

        } else if (day == "yesterday") {
          start = formatDate(new Date().getTime() - 3600*1000*24, 'YY-MM-DD')
          end = formatDate(new Date().getTime(), 'YY-MM-DD')

        } else {
          start = formatDate(new Date().getTime() - 3600*1000*24*parseInt(day), 'YY-MM-DD')
          end = formatDate(new Date().getTime()+3600*1000*24, 'YY-MM-DD')
        }

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
                  var b = format_bandwidth(value)
                  var format = "YY/MM/DD hh:mm"
                  if (date.length == 10) {
                    format = "YY/MM/DD"
                  }
                  return formatDate(date,format) + " <br>" + "带宽: " + b
              },
          },
          xAxis: {
              type: 'category',
              data:[],
              axisLabel: {
                formatter: function (value, index) {
                  var format = "MM/DD hh:mm"
                  if (value.length == 10) {
                    format = "MM/DD 00:00"
                  }
                  return formatDate(value,format)
                }
              }
          },
          yAxis: {
              type: 'value',     
              axisLabel: {
                formatter: function (value, index) {
                  return format_bandwidth(value)
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
                    var t = (v / 1024 /1024).toFixed(2) + " GB" 
                  } else if (v >= 921.6) {
                    var t = (v / 1024).toFixed(2) + " MB" 
                  } else {
                    var t = v.toFixed(2) + " KB"
                  }        

                  var format = "YY/MM/DD hh:mm"
                  if (date.length == 10) {
                    format = "YY/MM/DD"
                  }

                  return formatDate(date,format) + " <br>" + "流量: " + t
              },
          },
          xAxis: {
              type: 'category',
              data:[],
              axisLabel: {
                formatter: function (value, index) {
                  var format = "MM/DD hh:mm"
                  if (value.length == 10) {
                    format = "MM/DD 00:00"
                  }
                  return formatDate(value,format)
                }
              }
          },
          yAxis: {
              type: 'value',     
              axisLabel: {
                formatter: function (value, index) {
                  var v = value / 1024
                  if (v >= 943718.4) {
                    return (v / 1024 /1024).toFixed(2) + " GB" 
                  } else if (v >= 921.6) {
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

    }

    ]

    // 定时更新
    function interval_update() {

      function get_data(index) {
          var type = window.chart_option[index]["id"]
          var range = get_date_range()
          var start = encodeURI(range[0])
          var end = encodeURI(range[1])

          // user_package
          var user_package = $("input[name='user_package']").val()

          // ports
          var ports = $("input[name='res']").val()     

          // uid
          var uid = undefined
          var select_uid = $("select[name='users']").val()
          if (select_uid) {
            uid = select_uid
          }
          
          var url 
          if (uid) {
            url = '/monitor/usage?cate=stream&type='+type+'&start='+start+'&end=' + end + '&res='+ports+'&user_package='+user_package+'&uid='+uid
          } else {
            url = '/monitor/usage?cate=stream&type='+type+'&start='+start+'&end=' + end + '&res='+ports+'&user_package='+user_package
          }

          admin.req({
            url: url //实际使用请改成服务端真实接口
            ,type: "get"
            ,loader: false
            ,done: function(res){
              window.chart_ins[index].hideLoading();
              if (type == "bandwidth") {
                var max_value = format_bandwidth(res.max_value)
                var max_95_value = format_bandwidth(res.max_95_value)
                $("#max-value").text(max_value)
                $("#max-95-value").text(max_95_value)
              }

              //登入成功的提示与跳转
              var data = res.data
              var x = []
              var y = []
              var option = window.chart_option[index]["option"]

              // 带宽
              if (index == 0) {
                table.reload("bandwidth-table", {data: data}); //表格重载

              // 流量
              } else {
                table.reload("traffic-table", {data: data}); //表格重载
              }

              //数据为空
              if (data.length == 0) {
                option["xAxis"]["data"] = [0]
                option["series"][0]["data"] = [0]
                window.chart_ins[index].setOption(option,true);
                return                
              }

              for (j in data) {
                x.push(data[j]["date"])
                y.push(data[j]["value"])
              }
              option["series"][0]["data"] = y

              option["xAxis"]["data"] = x
              window.chart_ins[index].setOption(option,true);


            }
          });          
      } 

      // 设置定时，当前tab
      var curr_tab = $(".layui-tab-title .layui-this").text()
      if (curr_tab == "带宽") {
        get_data(0)

      } else if (curr_tab == "流量") {
        get_data(1)
      }
    }

    // 初始化图表
    window.chart_ins = []
    for (i in window.chart_option) {
      window.chart_ins[i] = render_chart(window.chart_option[i]["id"], window.chart_option[i]["option"])
    }

    // 初始化表格
    table.render({
      elem: '#bandwidth-table'
      ,cols: [[
        {field:'date', title:"时间"}
        ,{field:'value', title:'带宽',sort:true,templet:function (d) {
            var v = d.value * 8 / 1000
            if (v >= 900000) {
              var t = (v / 1000/1000).toFixed(2) + " Gbps" 
            } else if (v >= 921.6) {
              var t = (v / 1000).toFixed(2) + " Mbps" 
            } else {
              var t = v.toFixed(2) + " Kbps"
            }
            return t
        }}
      ]]
      ,data: []
      ,limit: 1000
    });

    table.render({
      elem: '#traffic-table'
      ,totalRow: true
      ,cols: [[
        {field:'date', totalRowText: "总流量：",title:"时间"}
        ,{field:'value', title:'流量',totalRow: true,sort:true, templet:function (d) {
            var v = d.value / 1024
            if (v >= 943718.4) {
              var t = (v / 1024/1024).toFixed(2) + " GB" 
            } else if (v >= 921.6) {
              var t = (v / 1024).toFixed(2) + " MB" 
            } else {
              var t = v.toFixed(2) + " KB"
            }
            return t
        }}
      ]]
      ,data: []
      ,limit: 1000
    });

    // 开始首tab间隔更新
    interval_update()

    element.on('tab(stream-usage-tab)', function(data){
      // resize
      for (i in window.chart_ins) {
        window.chart_ins[i].resize();
      }

      // update
      interval_update()

    });

  });
  
  exports('stream-usage-senior', {})
});