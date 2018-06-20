launchModal = (id)->
  $('.ttip').tooltip('hide')
  $('.obf').tooltip('hide')
  $('.obu').tooltip('hide')
  $('.cancelOffer').tooltip('hide')
  selectMatButton("#mat0")
  updateContribution(20)
  setTitleType()
  setExp()
  $("#{id}").modal { keyboard: true, focus: true, show: true }

setSide = (side)-> $('#side').attr("value", side)
getSide = -> $('#side').attr("value")

selectMatButton = (id)->
  $("#maturation > label").removeClass("active")
  $("#maturation > input").attr("checked", false)
  $("#{id}").attr("checked", true)
  $("#{id}").parent().addClass("active")

setExp = ->
  mDate   = $('#maturation input:checked').val()
  tDate   = $('#today').val()
  lst1 = _.map([1..10], (idx) -> moment(tDate).add(idx*3, 'days').format("YYYY-MM-DD"))
  lst2 = lst1.concat([mDate])
  lst3 = _.uniq(lst2)
  lst4 = _.select(lst3, (str) -> tDate < str <= mDate)
  $('#expSel').empty()
  dateLbl = moment(tDate).format("MMM DD")
  $('#expSel').append("<option value='#{tDate}' select='selected'>#{dateLbl}</option>")
  _.each lst4, (dateStr)->
    dateLbl = moment(dateStr).format("MMM DD")
    $('#expSel').append("<option value='#{dateStr}'>#{dateLbl}</option>")

updateContribution = (value)->
  side = getSide()
  factor = switch side
    when "unfixed" then 0.8
    when "fixed" then 0.2
  result = value * factor
  console.log result
  console.log side
  $('#contribution').text(result)

setTitleType = ->
  label = switch getSide()
    when "unfixed" then "Fund"
    when "fixed" then "Fix"
  $('#titleType').text(label)

$('#valueSel').change ->
  value = parseInt($('#valueSel').val())
  updateContribution(value)

$('#maturation').change setExp

$('.exDate').tooltip(html: true)
$('.cancelOffer').tooltip(title: "Cancel your offer")

$('.ttip').tooltip(title: "Click to sell your position")
$('.ttip').click (event) ->
  pos_uuid = $(event.target).attr('id')
  ixid = $(event.target).data('ixid')
  oval = $(event.target).data('oval')
  $('#mform').attr('action', "/position_sell/#{pos_uuid}")
  $('#ixid').text(ixid)
  $('#oval').text(oval)
  launchModal("#modalOs")

$('.obu').tooltip(title: "Create a new offer to fund")
$('.obu').click (_event) ->
  setSide("unfixed")
  launchModal("#modalOb")

$('.obf').tooltip(title: "Create a new offer to fix")
$('.obf').click (_event) ->
  setSide("fixed")
  launchModal("#modalOb")
