// SPDX-License-Identifier: MPL-2.0
$(function() {
  var sec_per_day = parseInt($('body').attr('seconds_per_day'))
  if(sec_per_day < 1) {
    sec_per_day = 1
  }
  function seconds_to_timeofday(sec){
    days = Math.floor(sec / sec_per_day)
    sec2 = sec % sec_per_day
    hours = Math.floor(sec2*24/sec_per_day)
    sec2 = (sec2*24) % sec_per_day
    minutes = Math.ceil(sec2/60)
    result = ""
    if( days > 0) {
    result += days + 'd '
    }
    if( hours < 12) {
      result += "" + hours + "am"
    } else {
      if( hours > 12){
        hours -= 12
      }
      result += hours + "pm"
    }
    return result
  }
  function seconds_to_hours(sec){
    days = Math.floor(sec / sec_per_day)
    sec2 = sec % sec_per_day
    hours = Math.ceil(sec2*24/sec_per_day)
    result = ""
    if( days > 0) {
    result += days + 'd '
    }
    result += "" + hours + "h"
    return result
  }

  //console.log(sec_per_day)
  var x = setInterval(function(){
    $('.updatecal').each(function(){
      sec = parseInt($(this).attr("seconds_into_day")) + 1
      date = new Date($(this).attr("date"))
      date_opt = {month: 'short', day: 'numeric'}
      if(sec < 0){
        // don't allow negative numbers
        sec = 0
      }
      if( sec >= sec_per_day){
        //next day
        date.setDate(date.getDate() + Math.floor(sec/sec_per_day))
        $(this).attr("date", date.toDateString())
        sec = sec % sec_per_day
      }
      $(this).text(new Intl.DateTimeFormat('en-US', date_opt).format(date) + ', ' + seconds_to_timeofday(sec))
      $(this).attr("seconds_into_day", sec)
    })
    $('.countdown').each(function(){
      sec = parseInt($(this).attr("secs")) - 1
      if(sec <= 0){
        sec = 0
        if ($(this).parents('table#accountqueue').length) {
          $(this).parent('td').text('Completed')
          // idea: remove row... but add empty row if last row
        }
      } else {
        $(this).text(seconds_to_hours(sec))
        $(this).attr("secs", sec)
      }
    })
    $('.countdown-sec').each(function(){
      sec = parseInt($(this).attr("secs")) - 1
      $(this).text(sec)
      $(this).attr("secs", sec)
    })
    $('.queue_delay').each(function(){
      sec = parseInt($(this).attr("secs")) - 1
      $(this).attr("secs", sec)
      if(sec <= 0){
        dur = parseInt($(this).attr("duration"))
        new_html = "In progress: <span class='countdown' secs='" +
                   dur +
                   "'>" +
                   seconds_to_hours(dur) +
                  "</span> until completion";
        $(this).parent('td').html(new_html);
      }
    })
    $('.countup-sec').each(function(){
      sec = parseInt($(this).attr("secs")) + 1
      $(this).text(sec)
      $(this).attr("secs", sec)
    })
  }, 1000);
});
