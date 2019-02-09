# SPDX-License-Identifier: MPL-2.0
require 'time'
require 'yaml'
require 'csv'
require 'json'

module AppHelpers

  # trying to exclude line but have it available when useful
  if defined? ActionView
    # this line caused an error when including App Helpers as part of my script
    include ActionView::Helpers::DateHelper
  end

  def valid_json?(json)
      JSON.parse(json)
      return true
    rescue JSON::ParserError => e
      return false
  end

  def valid_yaml?(json)
      YAML.load(json)
      return true
    rescue
      return false
  end

  # ----- positions -----

  def position_count(user)
    return 0 unless user
    sellable_positions(user).count + buyable_positions.count
  end

  def sellable_positions(user)
    user.positions.unresolved.fixed.unoffered
  end

  def buyable_positions
    Offer::Sell::Fixed.open
  end

  # ----- date formatting -----
  def dvis(time = BugmTime.now)
    time.strftime("%b %d")
  end

  def dstr(time = BugmTime.now)
    time.strftime("%Y-%m-%d")
  end

  # ----- investment -----

  def invested_tokens(user)
    user.offers.pluck(:value).sum
  end

  # def underactivity_penalty(user)
  #   #binding.pry
  #   spread = invested_tokens(user) - TS.seed_balance
  #   [ 0, spread ].min
  # end

  # ----- events -----

  def clean_type(event)
    event.event_type.gsub("Event::", "")
  end

  def clean_payload(event)
    ex = %w(uuid encrypted_password exid stm_body stm_tracker_uuid html_url)
    event.payload.except(*ex)
  end

  def user_links(event)
    event.user_uuids.map do |x|
      "<a href='/events_user/#{x}'>#{x[0..5]}</a>"
    end.join(", ")
  end

  # ----- funding hold -----

  # def funding_count(user)
  #   user.offers.is_buy_unfixed.count
  # end

  # def funding_hold?(user)
  #   funding_count(user) < 5
  # end

  # def funding_hold_link
  #   "<a href='/help#trader' target='_blank'>FUNDING HOLD</a>"
  # end

  def account_lbl(user)
    # count = funding_count(user)
    # warn = funding_hold?(user) ? " / FUNDED #{count} of 5 " : ""
    "#{user_name(user)} / balance: #{user.token_available.to_i}"
  end

  # def successful_fundings(user)
  #   user.positions.unfixed.resolved.losing.count
  # end

  # def funding_bonus(user)
  #   (successful_fundings(user) * TS.fee_funding.to_i).to_f
  # end

  # ----- time -----

  def timezone
    BugmTime.now.strftime("%Z")
  end

  def timewords(alt_time = Time.now + 1.hour)
    time_ago_in_words(alt_time)
  end

  def eod_words
    distance_of_time_in_words(BugmTime.now, BugmTime.end_of_day)
  end

  def contract_maturation_words(contract)
    str = distance_of_time_in_words(BugmTime.now, contract.maturation)
    BugmTime.now > contract.maturation ? "#{str} ago" : "in #{str}"
  end

  def eod_iso
    BugmTime.end_of_day.strftime("%Y%m%dT%H%M%S")
  end

  def real_seconds_to_simulated_hours(sec)
    sec_per_day = TS.nightly_scr["seconds_for_day_switching"]
    days = (sec / sec_per_day).floor
    sec2 = sec % sec_per_day
    hours = (sec2*24/sec_per_day).floor

    result = ""
    if days > 0 then
      result = "#{result} #{days}d "
    end
    result = "#{result} #{hours}h"
    return result
  end

  # ----- info icon -----

  def i_circle
    "<i class='fa fa-info-circle'></i>"
  end

  def ic_link(tgt)
    "<a href='#{tgt}'>#{i_circle}</a>"
  end

  # ----- issues -----

  def self.issue_create(tracker)
    # find next id
    id = 1
    id += Issue.last.id unless Issue.last.nil?
    # prepare new issue
    opts = {
      stm_title: SecureRandom.hex(2),
      stm_tracker_uuid: tracker.uuid,
      stm_status: 'open',
      stm_body: ' ',
      exid: id
    }
    # create new issue
    issueid = FB.create(:issue, opts).issue.id
    # set skills requires for tasks on this issue
    skill_array = TS.skills["task_skills"].sample(TS.skills["number_of_skills_per_issue"])
    myhash = {"skill"=> {}}
    skill_array.each do |i|
      myhash["skill"]["#{i}"] = 0
    end
    myhash["created_at"] = BugmTime.now.strftime("%Y-%m-%d")
    myhash["first_activity"] = ""
    myhash["last_activity"] = ""
    sql = "UPDATE issues SET jfields = '#{JSON.generate(myhash)}' WHERE id='#{issueid}';"
    #binding.pry
    ActiveRecord::Base.connection.execute(sql)
  end

  def issue_offerable?(user, issue)
    issue.offers.where('expiration > ?', BugmTime.now).pluck(:user_uuid).include?(user.uuid)
  end

  def issue_id_link(issue)
    "<a href='/issues/#{issue.uuid}'>Issue ##{issue.id}</a>"
  end

  def issue_status(issue)
    issue.stm_status
  end

  def issue_value(issue)
    issue.offers.open.pluck(:value).sum
  end

  def issue_color(issue)
    issue_status(issue) == "open" ? "#4c1" : "#721"
  end

  # ----- offers -----

  def self.offer_create_bu(user, issue, price, volume, maturation, aon = true, poolable = false)

      # args is a hash
      args  = {
        aon: aon,
        poolable: poolable,
        user_uuid: user.uuid,
        price: price,
        volume: volume,
        stm_issue_uuid: issue.uuid,
        stm_tracker_uuid: issue.stm_tracker_uuid,
        maturation: BugmTime.end_of_day(maturation),
        expiration: BugmTime.end_of_day(maturation)
      }
      offer = FB.create(:offer_bu, args).project.offer
      ContractCmd::Cross.new(offer, :expand).project
      offer.uuid
  end

  def offer_id_link(offer)
    "<a href='/offers/#{offer.uuid}'>#{offer.xid}</a>"
  end

  def offer_status(offer)
    offer.status
  end

  def offer_value(offer)
    offer.value
  end

  def offer_color(offer)
    offer.status == "open" ? "#4c1" : "#721"
  end

  def offer_maturation_date(offer)
    return "TBD" if offer.expiration.nil?
    # color = BugmTime.now > offer.expiration ? "red" : "green"
    date = offer.expiration.strftime("%Y-%m-%d").to_date.mjd - BugmTime.now.to_date.mjd
    if date > 1 then
      return "In #{date} days"
    elsif date == 1 then
      return "Tomorrow"
    elsif date < -1 then
      return "#{date * -1} days ago"
    elsif date == -1 then
      return "Yesterday"
    else
      return "Today"
    end
    # date_iso = offer.expiration.strftime("%Y%m%dT%H%M%S")
    # "<a target='_blank' style='color: #{color}' href='https://www.timeanddate.com/worldclock/fixedtime.html?iso=#{date_iso}&p1=217'>#{date}</a>"
    # date
  end

  def offer_status_link(offer)
    case offer.status
    when 'crossed'
      "<a href='/contracts/#{offer.position.contract.uuid}'>offer is accepted</a>"
    else
      offer.status
    end
  end

  def offer_sell_link(position)
    ixid = position.offer.issue.xid.capitalize
    oval = position.value.to_i
    "
    <a href='#' class='ttip' data-oval='#{oval}' data-ixid='#{ixid}' data-toggle='tooltip' id='#{position.uuid}'>
    #{user_name(position.user)}
    </a>
    "
  end

  def sellable_fixed_position(user, position)
    return false unless position.user == user
    user.positions.unresolved.fixed.unoffered.include?(position)
  end

  def sellable_unfixed_position(user, position)
    return false unless position.user == user
    user.positions.unresolved.unfixed.unoffered.include?(position)
  end


  def offer_worker_link(user, offer, action = "offer_accept")
    case offer.status
    when 'crossed'
      if offer.type.include? "::Unfixed" then
        position = offer.position.counterpositions.first
      else
        position = offer.position
      end
      # disable CreateSell
      # if sellable_fixed_position(current_user, position)
        # offer_sell_link(position)
      # else
        user_name(position.user)
      # end
    when 'expired'
      if offer.type.include? "::Fixed" then
        user_name(offer.user)
      else
        '<i>expired not accepted</i>'
      end
    when 'canceled'
      if offer.type.include? "::Fixed" then
        user_name(offer.user)
      else
        '<i>canceled</i>'
      end
    when 'open'
      if offer.type.include? "::Fixed" then
        user_name(offer.user)
      else
        if offer.user.uuid == user.uuid
          "<a class='btn btn-primary btn-sm disabled' href='#'>cannot accept your own offer</a>"
        else
          cost = offer.fixer_cost.to_i
          "<a class='btn btn-primary btn-sm' href='/#{action}/#{offer.uuid}'>ACCEPT OFFER (cost: #{cost} tokens)</a>"
        end
      end
    end
  end

  def offer_funder_link(user, offer, action = "offer_accept")
    case offer.status
    when 'crossed'
      if offer.type.include? "::Fixed" then
        position = offer.position.counterpositions.first
      else
        position = offer.position
      end
      # disable resell
      # if sellable_unfixed_position(current_user, position)
        # offer_sell_link(position)
      # else
        user_name(position.user)
      # end
    when 'expired'
      if offer.type.include? "::Unfixed" then
        user_name(offer.user)
      else
        '<i>expired not accepted</i>'
      end
    when 'canceled'
      if offer.type.include? "::Unfixed" then
        user_name(offer.user)
      else
        '<i>canceled</i>'
      end
    when 'open'
      if offer.type.include? "::Unfixed" then
        user_name(offer.user)
      else
        if offer.user.uuid == user.uuid
          "<a class='btn btn-primary btn-sm disabled' href='#'>cannot accept your own offer</a>"
        else
          cost = offer.fixer_cost.to_i
          "<a class='btn btn-primary btn-sm' href='/#{action}/#{offer.uuid}'>ACCEPT OFFER (cost: #{cost} tokens)</a>"
        end
      end
    end
  end

  def offer_awardee(offer)
    return "ready to be accepted" if offer.status == 'open'
    return "canceled" if offer.status == 'canceled'
    return "expired on maturation; not accepted" if offer.status == 'expired'
    return "waiting for maturation" if offer.position.contract.status != 'resolved'
    user = Position.where("amendment_uuid = '#{offer.position.amendment.uuid}' AND side = '#{offer.position.contract.awardee}'").first.user
    # user = offer.escrow.where(side: contract.awardee).first.user
    if user.uuid == offer.user.uuid then
      user_type = "trader"
    else
      user_type = "worker"
    end
    "#{user_type} <b>#{user_name(user)}</b> received #{offer.volume.to_i} tokens"
  end

  # ----- contracts -----

  def contract_id_link(contract)
    "<a href='/contracts/#{contract.uuid}'>#{contract.xid}</a>"
  end

  def contract_mature_date(contract)
    return "TBD" if contract.maturation.nil?
    # color = BugmTime.now > offer.expiration ? "red" : "green"
    date = contract.maturation.strftime("%Y-%m-%d").to_date.mjd - BugmTime.now.to_date.mjd
    if date > 1 then
      return "In #{date} days"
    elsif date == 1 then
      return "In #{date} day"
    elsif date < -1 then
      return "#{date * -1} days ago"
    elsif date == -1 then
      return "#{date * -1} day ago"
    else
      return "In 0 days"
    end
    # color = BugmTime.now > contract.maturation ? "red" : "green"
    # date = contract.maturation.strftime("%m-%d %H:%M %Z")
    # "<span style='color: #{color};'>#{date}</span>"
  end


  def contract_status(contract)
    case contract.status
    when "open"     then "open"
    when "matured"  then "matured"
    when "resolved" then "resolved"
    else "UNKNOWN_CONTRACT_STATE"
    end
  end

  def contract_earnings(user, contract)
    return "waiting for maturation" unless contract.resolved?
    contract.value_for(user)
  end

  def fixed_username(contract)
    user_name(contract.positions.fixed.first.user)
  end

  def unfixed_username(contract)
    user_name(contract.positions.unfixed.first.user)
  end

  def escrow_awardee(escrow)
    return "NA" if escrow.contract.status != 'resolved'
    user = Position.where("amendment_uuid = '#{escrow.amendment.uuid}' AND side = '#{escrow.contract.awardee}'").first.user
    # user = escrow.position.where(side: contract.awardee).first.user
    user_name(user)
  end

  # ----- links -----

  def repo_link
    url = TS.repo_url
    "<a href='http://#{url}' target='_blank'>Document Repo</a>"
  end

  def tracker_btn(issue = nil, label = nil)
    type = TS.tracker_type.to_s
    url = case type
      when "yaml"   then yaml_tracker_url(issue)
      when "github" then github_tracker_url(issue)
    end
    lbl = label || (type.capitalize + " ##{issue.sequence}")
    kls = "btn.btn-sm.btn-primary"
    "<a class='#{kls}' role='button' href='#{url}' target='_blank'>#{lbl}</a>"
  end

  def tracker_link(issue = nil, label = nil)
    url = case TS.tracker_type.to_sym
      when :yaml   then yaml_tracker_url(issue)
      when :github then github_tracker_url(issue)
    end
    lbl = label || url
    "<a href='#{url}' target='_blank'>#{lbl}</a>"
  end

  def github_tracker_url(issue)
    base = "http://github.com/#{TS.tracker_name}/issues"
    issue ? "#{base}/#{issue.sequence}" : base
  end

  def current_page(path)
    request.path_info == path
  end

  def btn_start_stop_nightly
    da = false # deactivated
    da = true unless $current_session.nil?
    if $run_nightly.nil? then
      return "<a href='/admin/startstopnighlty' class='btn btn-secondary #{'disabled' if da}'>Simulation NOT running</a>"
    else
      return "<a href='/admin/startstopnighlty' class='btn btn-success #{'disabled' if da}'> Stop Simulation</a>"
    end
  end

  # ----- ytrack -----

  def yaml_tracker_url(issue)
    base = "http://#{TS.webapp_url}/ytrack"
    issue ? "#{base}/#{issue.exid}" : base
  end

  def ytrack_nav_menu
    iora = Iora.new(TS.tracker_type, TS.tracker_name)
    iora.issues.map do |el|
      label = el["stm_title"]
      exid  = el["exid"]
      ytrack_nav(label, "/ytrack/#{exid}")
    end.join
  end

  def ytrack_nav(label, path)
    href = "<a href='#{path}'>#{label}</a>"
    link = current_page(path) ? label :  href
    """
    <hr style='margin:0; padding:0;'/>
    #{link}
    """
  end

  def ytrack_action_btn(issue)
    lbl = issue['stm_status'] == "open" ? "close" : "open"
    "<a href='/ytrack_#{lbl}/#{issue["exid"]}' class='btn btn-sm btn-primary'>click to #{lbl}</a>"
  end

  # -----

  def help_nav(label, path)
    href = "<a href='#{path}'>#{label}</a>"
    link = current_page(path) ? label :  href
    """
    <hr/>
    #{link}
    """
  end

  def base_link(label, path, jump = nil)
    tgt = jump ? "target=_blank" : ""
    href = "<a href='#{path}' #{tgt}>#{label}</a>"
    current_page(path) ? label :  href
  end

  def nav_btn(label, path)
    active = current_page(path) ? 'active' : ''
    """
    <li class='nav-item #{active}'>
      <a class='nav-link btn-like' role='button' href='#{path}'>#{label}</a>
    </li>
    """
  end

  def nav_link(label, path)
    active = current_page(path) ? 'active' : ''
    """
    <li class='nav-item #{active}'>
      <a class='nav-link' href='#{path}'>#{label}</a>
    </li>
    """
  end

  def nav_text(label)
    """
    <li class='nav-item'>
      <span class='navbar=text'>#{label}</span>
    </li>
    """
  end

  def link_uc(label, path, opts = {})
    if current_page(path)
      return "" if opts[:hide] || opts["hide"]
      label
    else
      "<a href='#{path}'>#{label}</a>"
    end
  end

  # ----- auth / consent -----

  def current_user
    @current_user ||= User.find_by_email(session[:usermail])
  end

  def consented?
    session[:consent]
  end

  def user_mail
    current_user&.email
  end

  def user_name(user = current_user)
    if user && user.class == User
      user.name || user.uuid[0..5]
    else
      "err"
    end
  end

  def logged_in?
    current_user
  end

  def valid_consent(user)
    AccessLog.new(user&.email).has_consented?
  end

  def admin_only!
    protected!
    redirect "/account" unless current_user.id == 1
  end

  def protected!
    authenticated!
    consented!
    wait!
    survey!
  end

  def authenticated!
    return if logged_in?
    flash[:danger]     = "Please log in"
    session[:tgt_path] = request.path_info
    redirect "/login"
  end

  def consented!
    return if consented?
    redirect "/consent_form"
  end

  def wait!
    # admin does not need to wait
    return if current_user.id == 1
    # only let participants wait if requested
    return unless $session_wait
    redirect "/wait"
  end

  def survey!
    # admin does not need to take survey
    return if current_user.id == 1
    # only redirect to survey if set
    return unless $session_survey
    redirect "/questions"
  end

  # ----- offer helpers

  def issue_title(offer)
    offer.issue.stm_title
  end

  def issue_word(offer)
    issue_title(offer).split("_").first
  end

  def issue_type(offer)
    letter = issue_title(offer).split("_").last[0]
    case letter
      when "c" then "Comment"
      when "p" then "PR"
      else "NA"
    end
  end

  def issue_hint(offer)
    issue_title(offer)[-1]
  end

  def start_date
    xformat TS.start_date
  end

  def finish_date
    xformat TS.finish_date
  end

  def xformat(time)
    time.strftime("%B %d")
  end

  def participant_list(args = {})
    puts args.inspect
    TS.participants.sort.map do |email|
      args[:obfuscated] ? obfuscate(email) : email
    end.join(", ")
  end

  def obfuscate(email)
    name, domain = email.split('@')
    comp, ext = domain.split(".")
    "<code>#{name}@#{comp.gsub(/./, '*')}.#{ext}</code>"
  end

  #------work Queue ------

  def queue_task_time(task, user = current_user)
    # if user.nil? then
    #   user = current_user
    # end
    if user.jfields["skill_malus"].nil? || user.jfields["skill_bonus"].nil? then
      return TS.skills['seconds_per_normal_skill']
    end
    if user.jfields["skill_malus"].include?(task) then
      return TS.skills['seconds_per_malus_skill']
    end
    if user.jfields["skill_bonus"].include?(task) then
      return TS.skills['seconds_per_bonus_skill']
    end
    return TS.skills['seconds_per_normal_skill']
  end

  def queue_add_task(user_uuid, issue_uuid, task, user = current_user)
    datesql = "Select max(completed) from work_queues where user_uuid = '#{user_uuid}' and completed > now() and removed IS NULL;"
    maxdate = ActiveRecord::Base.connection.execute(datesql).to_a
    #maxdate = JSON.parse(maxdate1)['max']
    if maxdate[0]["max"].nil?
      startdate = 'now()'
    else
     startdate = "(timestamp '#{maxdate[0]["max"]}')"
    end
    sql = "INSERT INTO work_queues (user_uuid, issue_uuid, task, added_queue, position, completed, startwork)
    values ('#{user_uuid}','#{issue_uuid}','#{task}',
      '#{BugmTime.now.to_s.slice(0..18)}', 1, #{startdate} + '#{queue_task_time(task, user)} seconds',#{startdate}) ;"
    ActiveRecord::Base.connection.execute(sql).to_a
  end

  # for use with get/post requests (duplicate below)
  def queue_remove_task(queue_id)
    queue_id = ActiveRecord::Base.connection.quote(queue_id)
    getqueuesql = "SELECT user_uuid
                        , startwork
                        , EXTRACT(EPOCH FROM (completed - startwork))::numeric::integer AS full
                        , EXTRACT(EPOCH FROM(completed - current_timestamp))::numeric::integer AS partial
                  FROM work_queues WHERE id=#{queue_id} ;"
    shifts = ActiveRecord::Base.connection.execute(getqueuesql).first
    if shifts['partial'] > 2
      cancelsql = "UPDATE work_queues SET removed = NOW() WHERE id=#{queue_id} ;"
      ActiveRecord::Base.connection.execute(cancelsql)
      if shifts['partial'] < shifts['full']
        shift = "'#{shifts['partial']} seconds'"
      elsif
        shift = "'#{shifts['full']} seconds'"
      end
      cancelsql = "UPDATE work_queues SET completed = completed - INTERVAL #{shift}, startwork = startwork - INTERVAL #{shift}
      WHERE startwork > timestamp '#{shifts["startwork"]}' AND user_uuid = '#{shifts["user_uuid"]}'  ;"
      shifts = ActiveRecord::Base.connection.execute(cancelsql)
    end
  end

  # for use in work_queue_sync (duplicate above)
  def self.queue_remove_task(queue_id)
    queue_id = ActiveRecord::Base.connection.quote(queue_id)
    getqueuesql = "SELECT user_uuid
                        , startwork
                        , EXTRACT(EPOCH FROM (completed - startwork))::numeric::integer AS full
                        , EXTRACT(EPOCH FROM(completed - current_timestamp))::numeric::integer AS partial
                  FROM work_queues WHERE id=#{queue_id} ;"
    shifts = ActiveRecord::Base.connection.execute(getqueuesql).first
    if shifts['partial'] > 2
      cancelsql = "UPDATE work_queues SET removed = NOW() WHERE id=#{queue_id} ;"
      ActiveRecord::Base.connection.execute(cancelsql)
      if shifts['partial'] < shifts['full']
        shift = "'#{shifts['partial']} seconds'"
      elsif
        shift = "'#{shifts['full']} seconds'"
      end
      cancelsql = "UPDATE work_queues SET completed = completed - INTERVAL #{shift}, startwork = startwork - INTERVAL #{shift}
      WHERE startwork > timestamp '#{shifts["startwork"]}' AND user_uuid = '#{shifts["user_uuid"]}'  ;"
      shifts = ActiveRecord::Base.connection.execute(cancelsql)
    end
  end

  def task_action(task,issue_uuid,status)
    queue_item = Work_queue.where(user_uuid: current_user.uuid).where(issue_uuid: issue_uuid).where(task: task).where(removed: [nil, ""])
    if status == 1
      out2 = "Task is completed"
    elsif queue_item.present?
      out2 = "<form class='form-work' method='post' action='/issue_task_queue_remove/#{issue_uuid}'>
                You plan to work on it <button class='btn btn-sm btn-secondary' type='submit' value='#{queue_item.first.id}' name='Cancel'>Remove from my Queue</button>
              </form>"
    else
      out2 = "<form class='form-work' method='post' action='/issue_task_queue/#{issue_uuid}'>
                <button class='btn btn-sm btn-primary' type='submit' value='#{task}' name='task'>Add task to my Queue</button>
              </form>"
    end
    return out2
  end

  #-------work Queue Progress -------

  def progress(startwork, endwork)
    if DateTime.now.to_time.to_i < startwork.to_time.to_i
      sec = endwork.to_time.to_i - startwork.to_time.to_i
      return "Queued: <span class='queue_delay' secs='#{startwork.to_time.to_i - DateTime.now.to_time.to_i}' duration='#{sec}'>requires #{real_seconds_to_simulated_hours(sec)} to complete</span>"
    elsif DateTime.now.to_time.to_i < endwork.to_time.to_i
      sec = endwork.to_time.to_i - DateTime.now.to_time.to_i
      return "In progress: <span class='countdown' secs='#{sec}'>#{real_seconds_to_simulated_hours(sec)}</span> until completion"
    else
      # not needed, since we don't display these
      return "Completed"
    end
  end

  def queue_length(user = current_user)
    # TODO: finish this function
    result = Work_queue.where(user_uuid: user.uuid).where(removed: [nil, ""]).where("completed > localtimestamp").pluck("MAX(completed) AS completein")[0]
    if result.nil?
      return "Your queue is empty, <strong>next task you add</strong> will be worked on immediately."
    else
      sec = result.to_s.to_datetime.to_i - Time.now.to_i
      cnt = Work_queue.where(user_uuid: user.uuid).where(removed: [nil, ""]).where("completed > localtimestamp").count
      return "Your queue is has #{cnt} tasks, the <strong>next task you add</strong> will begin in <span class='countdown' secs='#{sec}'>#{real_seconds_to_simulated_hours(sec)}</span>."
    end
  end

  # ------ Delete Comment on an issue----
  def delete_comment(id, user_uuid)
    if user_uuid == current_user.uuid
      output = "<form class='form-work' method='post' action='/issue_comments_delete'>
                <button class='btn btn-sm btn-primary' type='submit' value='#{id}' name='id'>Delete</button>
              </form>"
    else
     output = "You can not delete other user's comments"
    end
    return output
  end


  # generating data for graphs
  def self.grafana_graph_data(timeobject = BugmTime.now)
    # Graph data for Contract fixed rate vs total

    # Make sure all data points are on the same time point
    timestamp = timeobject.to_i
    # do this for each project
    Tracker.pluck('uuid').each do |project_uuid|

    # Graph data for Variance of offer prices
    sql = "SELECT MIN(price) AS minprice
              , MAX(price) AS maxprice
              , AVG(price) AS avgprice
              FROM offers
              JOIN issues ON offers.stm_issue_uuid=issues.uuid
              WHERE status = 'open'
              AND offers.type = 'Offer::Buy::Unfixed'
              AND issues.stm_tracker_uuid = '#{project_uuid}';"
    result = ActiveRecord::Base.connection.execute(sql).to_a.first
    minprice =result['minprice'].to_f
    maxprice = result['maxprice'].to_f
    avgprice = result['avgprice'].to_f
    if USE_INFLUX == true
      args = {
        tags: {
          graph: "variance_of_price",
          project: "#{project_uuid}",
          project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
        },
        values: {minprice: minprice, maxprice: maxprice, avgprice: avgprice},
        timestamp: timestamp
      }
      InfluxStats.write_point "GraphData", args
    end

    # Graph data for Offer count and volume
    sql = "SELECT SUM(volume) AS vol
              , COUNT(*) AS total
              FROM offers
              JOIN issues ON offers.stm_issue_uuid=issues.uuid
              WHERE status = 'open'
              AND issues.stm_tracker_uuid = '#{project_uuid}';"
    result = ActiveRecord::Base.connection.execute(sql).to_a.first
    vol = result['vol'].to_f
    total = result['total'].to_f
    if USE_INFLUX == true
      args = {
        tags: {
          graph: "open_offer_count_and_volume",
          project: "#{project_uuid}",
          project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
        },
        values: {offer_volume: vol, offer_count: total},
        timestamp: timestamp
      }
      InfluxStats.write_point "GraphData", args
    end

    # Graph data for skills in demand
    sql = "SELECT count(CASE WHEN jfields->'skill'->>'Python' = '0' THEN 1 END) AS has_python
          , count(CASE WHEN jfields->'skill'->>'SQL' = '0' THEN 1 END) AS has_sql
          , count(CASE WHEN jfields->'skill'->>'PHP' = '0' THEN 1 END) AS has_php
          , count(CASE WHEN jfields->'skill'->>'Java' = '0' THEN 1 END) AS has_java
          , count(CASE WHEN jfields->'skill'->>'Swift' = '0' THEN 1 END) AS has_swift
          , count(CASE WHEN jfields->'skill'->>'HTML' = '0' THEN 1 END) AS has_html
          , count(CASE WHEN jfields->'skill'->>'Ruby' = '0' THEN 1 END) AS has_ruby
          , count(CASE WHEN jfields->'skill'->>'C++' = '0' THEN 1 END) AS has_cpp
          FROM issues
          WHERE stm_tracker_uuid = '#{project_uuid}'
          AND stm_status = 'open';"
    result = ActiveRecord::Base.connection.execute(sql).to_a.first
    skill_demand = Hash.new
    skill_demand["Python"] = result['has_python'].to_f
    skill_demand["SQL"] = result['has_sql'].to_f
    skill_demand["PHP"] = result['has_php'].to_f
    skill_demand["Java"] = result['has_java'].to_f
    skill_demand["Swift"] = result['has_swift'].to_f
    skill_demand["HTML"] = result['has_html'].to_f
    skill_demand["Ruby"] = result['has_ruby'].to_f
    skill_demand["C++"] = result['has_cpp'].to_f
    if USE_INFLUX == true
      skill_demand.each do |key, value|
        args = {
          tags: {
            graph: "open_issue_skills",
            project: "#{project_uuid}",
            project_name: "#{Tracker.where(uuid: project_uuid).first.name}",
            skill: key
          },
          values: {tasks: value},
          timestamp: timestamp
        }
        InfluxStats.write_point "GraphData", args
      end
    end

    # Graph data for Offer count and volume
    sql = "SELECT count(*) AS new_comments FROM issue_comments
          JOIN issues ON issues.uuid = issue_comments.issue_uuid
          WHERE TO_CHAR(issue_comments.comment_date, 'YYYY-MM-DD') = '#{timeobject.strftime("%Y-%m-%d")}'
          AND issues.stm_tracker_uuid = '#{project_uuid}';"
    result = ActiveRecord::Base.connection.execute(sql).to_a.first
    new_comments = result['new_comments'].to_i
    if USE_INFLUX == true
      args = {
        tags: {
          graph: "new_comments",
          project: "#{project_uuid}",
          project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
        },
        values: {new_comments: new_comments},
        timestamp: timestamp
      }
      InfluxStats.write_point "GraphData", args
    end

      # # Contract Fix Rate
      # sql = "WITH f_contr AS (
      #       SELECT COUNT(*) AS fixed_contr
      #       FROM contracts
      #       JOIN issues ON contracts.stm_issue_uuid=issues.uuid
      #       WHERE awarded_to = 'fixed'
      #       AND TO_CHAR(maturation, 'YYYY-MM-DD') = '#{timeobject.strftime("%Y-%m-%d")}'
      #       AND issues.stm_tracker_uuid = '#{project_uuid}'
      #       )
      #       , a_contr AS (
      #       SELECT COUNT(*) AS all_contr
      #       FROM contracts
      #       JOIN issues ON contracts.stm_issue_uuid=issues.uuid
      #       WHERE to_char(maturation, 'YYYY-MM-DD') = '#{timeobject.strftime("%Y-%m-%d")}'
      #       AND issues.stm_tracker_uuid = '#{project_uuid}'
      #       )
      #       SELECT fixed_contr
      #       , all_contr
      #       , CASE WHEN all_contr=0 THEN 0.0 ELSE CAST(fixed_contr AS DOUBLE PRECISION)/CAST(all_contr AS DOUBLE PRECISION) END AS ratio
      #       FROM f_contr
      #       , a_contr;";
      # result =ActiveRecord::Base.connection.execute(sql).to_a.first
      # fixed = result['fixed_contr'].to_f
      # total = result['all_contr'].to_f
      # ratio = result['ratio'].to_f
      # if USE_INFLUX == true
      #   args = {
      #     tags: {
      #       graph: "fixed_total",
      #       project: "#{project_uuid}",
      #       project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
      #     },
      #     values: {fixedtotalratio: ratio, fixed_contract: fixed, total_contract: total},
      #     timestamp: timestamp
      #   }
      #   InfluxStats.write_point "GraphData", args
      # end

      # # Graph data for Payout vs Potential
      # sql = "WITH payout_sql AS (select SUM(fixed_value) + SUM(unfixed_value) AS payout
      #           FROM escrows
      #           JOIN contracts on escrows.contract_uuid = contracts.uuid
      #           JOIN issues on contracts.stm_issue_uuid=issues.uuid
      #           WHERE contracts.awarded_to = 'fixed'
      #           AND contracts.status = 'resolved'
      #           AND TO_CHAR(contracts.maturation, 'YYYY-MM-DD') = '#{timeobject.strftime("%Y-%m-%d")}'
      #           AND issues.stm_tracker_uuid = '#{project_uuid}'
      #         )
      #         , potential_sql AS (select SUM(fixed_value) + SUM(unfixed_value) AS potential
      #           FROM escrows
      #           JOIN contracts ON escrows.contract_uuid = contracts.uuid
      #           JOIN issues ON contracts.stm_issue_uuid=issues.uuid
      #           WHERE TO_CHAR(contracts.maturation, 'YYYY-MM-DD') = '#{timeobject.strftime("%Y-%m-%d")}'
      #           AND contracts.status = 'resolved'
      #           AND issues.stm_tracker_uuid = '#{project_uuid}'
      #         )
      #         SELECT payout
      #         , potential
      #         , CASE WHEN potential=0 THEN 0.0 ELSE CAST(payout AS DOUBLE PRECISION)/CAST(potential AS DOUBLE PRECISION) END AS ratio
      #         FROM payout_sql, potential_sql;"
      # result = ActiveRecord::Base.connection.execute(sql).to_a.first
      # payout = result['payout'].to_f
      # potential = result['potential'].to_f
      # ratio = result['ratio'].to_f
      # if USE_INFLUX == true
      #   args = {
      #     tags: {
      #       graph: "payout_potential",
      #       project: "#{project_uuid}",
      #       project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
      #     },
      #     values: {payoutpotentialratio: ratio, payout_contract: payout, potential_contract: potential},
      #     timestamp: timestamp
      #   }
      #   InfluxStats.write_point "GraphData", args
      # end

      # # Graph data for Variance of offer volumes
      # sql = "SELECT MIN(volume * price) AS minvol
      #           , MAX(volume * price) AS maxvol
      #           , AVG(volume * price) AS avgvol
      #           FROM offers
      #           JOIN issues ON offers.stm_issue_uuid=issues.uuid
      #           WHERE status = 'open'
      #           AND offers.type = 'Offer::Buy::Unfixed'
      #           AND issues.stm_tracker_uuid = '#{project_uuid}';"
      # result = ActiveRecord::Base.connection.execute(sql).to_a.first
      # minvol =result['minvol'].to_f
      # maxvol = result['maxvol'].to_f
      # avgvol = result['avgvol'].to_f
      # #path = File.expand_path("./public/csv/fixed_total.csv", __dir__)
      # if USE_INFLUX == true
      #   args = {
      #     tags: {
      #       graph: "variance_of_offer",
      #       project: "#{project_uuid}",
      #       project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
      #     },
      #     values: {minvol: minvol, maxvol: maxvol, avgvol: avgvol},
      #     timestamp: timestamp
      #   }
      #   InfluxStats.write_point "GraphData", args
      # end

      # # Graph data for Open Issues
      # open_issue = Issue.open.where(stm_tracker_uuid: project_uuid).count
      # if USE_INFLUX == true
      #   args = {
      #     tags: {
      #       graph: "open_issues",
      #       project: "#{project_uuid}",
      #       project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
      #     },
      #     values: {open_issues: open_issue},
      #     timestamp: timestamp
      #   }
      #   InfluxStats.write_point "GraphData", args
      # end

      # # Graph data for Closed Issues
      # closed_issue = Issue.closed.where(stm_tracker_uuid: project_uuid).count
      # if USE_INFLUX == true
      #   args = {
      #     tags: {
      #       graph: "closed_issues",
      #       project: "#{project_uuid}",
      #       project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
      #     },
      #     values: {closed_issues: closed_issue},
      #     timestamp: timestamp
      #   }
      #   InfluxStats.write_point "GraphData", args
      # end

      # # Graph data for Open Issue Age
      # sql = "SELECT SUM(CAST('#{timeobject.strftime("%Y-%m-%d")}' AS DATE) - CAST(CAST(jfields->'created_at' AS TEXT) AS DATE))/COUNT(*) AS avg_days
      #         FROM issues
      #         WHERE issues.stm_status = 'open'
      #         AND issues.stm_tracker_uuid = '#{project_uuid}';"
      # result = ActiveRecord::Base.connection.execute(sql).to_a.first
      # open_issue_age = result['avg_days'].to_f
      # if USE_INFLUX == true
      #   args = {
      #     tags: {
      #       graph: "open_issue_age",
      #       project: "#{project_uuid}",
      #       project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
      #     },
      #     values: {open_issue_age: open_issue_age},
      #     timestamp: timestamp
      #   }
      #   InfluxStats.write_point "GraphData", args
      # end

      # # Graph data for abandoned percentage of open issues (Issue Resolution Efficiency)
      # sql = "WITH total_count_tbl AS
      #         (
      #           SELECT CAST(COUNT(*) AS DOUBLE PRECISION) AS total_count_fld
      #           FROM issues
      #           WHERE issues.stm_status = 'open'
      #           AND issues.stm_tracker_uuid = '#{project_uuid}'
      #         )
      #         , abandoned_tbl AS
      #         (
      #           SELECT CAST(COUNT(*) AS DOUBLE PRECISION) AS abandoned_fld
      #           FROM issues
      #           WHERE issues.stm_status = 'open'
      #           AND CAST(jfields->>'last_activity' AS TEXT) < '#{BugmTime.now.advance(:days => -14).strftime("%Y-%m-%d")}'
      #           AND issues.stm_tracker_uuid = '#{project_uuid}'
      #         )
      #         SELECT CASE WHEN total_count_fld=0 THEN 0.0 ELSE abandoned_fld / total_count_fld END AS abandoned_pct
      #         FROM abandoned_tbl, total_count_tbl;"
      # result = ActiveRecord::Base.connection.execute(sql).to_a.first
      # abandoned_pct = result['abandoned_pct'].to_f
      # if USE_INFLUX == true
      #   args = {
      #     tags: {
      #       graph: "abandoned_vs_open",
      #       project: "#{project_uuid}",
      #       project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
      #     },
      #     values: {abandoned_vs_open: abandoned_pct},
      #     timestamp: timestamp
      #   }
      #   InfluxStats.write_point "GraphData", args
      # end

      # # Graph data for First Response Days
      # sql = "SELECT
      #           (
      #             CAST(
      #               SUM(
      #                 CAST(
      #                   CAST(
      #                     jfields->'first_activity' AS TEXT
      #                   ) AS DATE
      #                 )
      #                 -
      #                 CAST(
      #                   CAST(
      #                     jfields->'created_at' AS TEXT
      #                   ) AS DATE
      #                 )
      #               ) AS DOUBLE PRECISION
      #             )
      #             /
      #             CAST(
      #               COUNT(*) AS DOUBLE PRECISION
      #             )
      #           ) AS avg_days
      #         FROM issues
      #         WHERE
      #         (
      #           issues.stm_status = 'open'
      #           OR
      #           (
      #             issues.stm_status = 'closed'
      #             AND CAST(jfields->>'last_activity' AS TEXT) > '#{BugmTime.now.advance(:days => -14).strftime("%Y-%m-%d")}'
      #           )
      #         )
      #         AND issues.stm_tracker_uuid = '#{project_uuid}'
      #         AND jfields->>'first_activity' <> ''
      #         ;"
      # result = ActiveRecord::Base.connection.execute(sql).to_a.first
      # first_response_days = result['avg_days'].to_f
      # if USE_INFLUX == true
      #   args = {
      #     tags: {
      #       graph: "first_response_days",
      #       project: "#{project_uuid}",
      #       project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
      #     },
      #     values: {first_response_days: first_response_days},
      #     timestamp: timestamp
      #   }
      #   InfluxStats.write_point "GraphData", args
      # end

      # # Graph data for Issues Resolution Days ( Closed After Days)
      # sql = "SELECT
      #           (
      #             CAST(
      #               SUM(
      #                 CAST(
      #                   CAST(
      #                     jfields->'closed_on' AS TEXT
      #                   ) AS DATE
      #                 )
      #                 -
      #                 CAST(
      #                   CAST(
      #                     jfields->'created_at' AS TEXT
      #                   ) AS DATE
      #                 )
      #               ) AS DOUBLE PRECISION
      #             )
      #             /
      #             CAST(
      #               COUNT(*) AS DOUBLE PRECISION
      #             )
      #           ) AS avg_days
      #         FROM issues
      #         WHERE
      #         (
      #           issues.stm_status = 'closed'
      #           AND CAST(jfields->>'last_activity' AS TEXT) > '#{BugmTime.now.advance(:days => -100).strftime("%Y-%m-%d")}'
      #         )
      #         AND issues.stm_tracker_uuid = '#{project_uuid}'
      #         ;"
      # result = ActiveRecord::Base.connection.execute(sql).to_a.first
      # issue_resolution_days = 0
      # issue_resolution_days = result['avg_days'].to_f unless result.nil?
      # if USE_INFLUX == true
      #   args = {
      #     tags: {
      #       graph: "issue_resolution_days",
      #       project: "#{project_uuid}",
      #       project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
      #     },
      #     values: {issue_resolution_days: issue_resolution_days},
      #     timestamp: timestamp
      #   }
      #   InfluxStats.write_point "GraphData", args
      # end

      # Graph data for Average price
      # if USE_INFLUX == true
      #   prices = Offer.open.where(stm_tracker_uuid: project_uuid).where(type: 'Offer::Buy::Unfixed').pluck('price')
      #   if prices.count > 0
      #     avg_price = prices.avg
      #     args = {
      #       tags: {
      #         graph: "avg_price_buy_unfixed",
      #         project: "#{project_uuid}",
      #         project_name: "#{Tracker.where(uuid: project_uuid).first.name}"
      #       },
      #       values: {avg_price_buy_unfixed: avg_price},
      #       timestamp: timestamp
      #     }
      #     InfluxStats.write_point "GraphData", args
      #   end
      # end


    end #tracker.each
  end
  # ----- testing -----

  def hello
    raw("HELLO")
  end

  def h(text)
    Rack::Utils.escape_html(text)
  end

  def self.workqueue_sync
    # get completed tasks that have not updated issue yet
    un_marked_list_sql = "SELECT id, issue_uuid, task FROM work_queues
      WHERE updated_issue = FALSE
      AND completed < NOW()
      AND (removed > completed OR removed IS NULL); "
    un_marked_lists = ActiveRecord::Base.connection.execute(un_marked_list_sql).to_a

    # Update Issue table J-field for issue/task completed
    updated_ids = []
    un_marked_lists.each do |i|
      # collect ids of tasks that were used to update issues
      updated_ids.push(i['id'])
      # update issue that task is complete
      issue_update = "UPDATE issues
      SET jfields = replace(jfields::TEXT, '\"#{i["task"]}\": 0','\"#{i["task"]}\": 1')::jsonb
      WHERE uuid='#{i["issue_uuid"]}'
      ;"
      ActiveRecord::Base.connection.execute(issue_update)
      # update first activity on issue, if applicable
      issue_update_sql = "UPDATE issues
          SET jfields = jsonb_set(jfields, '{\"first_activity\"}', jsonb '\"#{BugmTime.now.strftime("%Y-%m-%d")}\"')
          WHERE uuid = '#{i["issue_uuid"]}'
          AND jfields->>'first_activity' = '';"
      ActiveRecord::Base.connection.execute(issue_update_sql)
      # update recent activity on issue
      issue_update_sql = "UPDATE issues
              SET jfields = jsonb_set(jfields, '{\"last_activity\"}', jsonb '\"#{BugmTime.now.strftime("%Y-%m-%d")}\"')
              WHERE uuid = '#{i["issue_uuid"]}';"
      ActiveRecord::Base.connection.execute(issue_update_sql)
      # remove queued tasks from other users for same task
      tasks_no_longer_needed_sql = "SELECT id FROM work_queues
      WHERE issue_uuid = '#{i['issue_uuid']}'
      AND task = '#{i['task']}'
      AND (removed > completed OR removed IS NULL)
      AND completed > NOW();"
      tasks_no_longer_needed = ActiveRecord::Base.connection.execute(tasks_no_longer_needed_sql).to_a
      tasks_no_longer_needed.each do |rem_task_id|
        queue_remove_task(rem_task_id.values[0])
      end
      # Check all the skills of an issue are worked on and mark it closed
      task_completed = Issue.where(uuid: "#{i["issue_uuid"]}").first.jfields["skill"]
      ex_id = Issue.where(uuid: "#{i["issue_uuid"]}").first.exid
      check = true
      task_completed.each do |key, value|
        if value == 0
          check = false
        end
      end
      if check == true
        IssueCmd::Sync.new({exid: ex_id, stm_status: "closed"}).project
        issue_update_sql = "update issues
                set jfields = jsonb_set(jfields, '{\"closed_on\"}', jsonb '\"#{BugmTime.now.strftime("%Y-%m-%d")}\"')
                WHERE exid = '#{ex_id}';"
        ActiveRecord::Base.connection.execute(issue_update_sql)
      end
    end
    # remember that issue was updated
    if updated_ids.length > 0
      work_queue_update_sql = "UPDATE work_queues SET updated_issue = TRUE WHERE id IN (#{updated_ids * ","});"
      ActiveRecord::Base.connection.execute(work_queue_update_sql)
    end
  end

  def self.record_bugm_system_times
    sql = "INSERT INTO bugmtimes (bugmtime, systime) VALUES ('#{BugmTime.now.strftime('%Y-%m-%d %H:%M:%S.%L')}', '#{Time.now.utc.strftime('%Y-%m-%d %H:%M:%S.%L')}');"
    ActiveRecord::Base.connection.execute(sql)
  end

  def self.resolve_matured_contracts
    Contract.pending_resolution.each do |contract|
         ContractCmd::Resolve.new(contract).project
    end
  end

  def self.expire_expired_offers
    Offer.open.expired_by_time.each do |offer|
      offer.update_attribute(:status, 'expired')
    end
  end

  def self.next_day
    # puts 'Running Nightly script'

    # puts 'Nightly Step 1: go past end of day'
    last_day = BugmTime.now
    BugmTime.go_past_end_of_day
    record_bugm_system_times

    # puts 'Nightly Step 2: resolve matured contracts'
    resolve_matured_contracts

    # puts 'Nightly Step 3: expire expired offers'
    expire_expired_offers

    # puts 'Nightly Step 4: generate data for graphs'
    grafana_graph_data(last_day)
  end

  def self.update_graphs
    # puts "Nightly Step 6: store graphs in static files"

    # get graphs that compare across projects
    threads = []
    # Market Metric: open offers across all projects
    threads.push(
      Thread.new do
        graphid="19"
        open("/tmp/bugm-sim-graph-#{graphid}", 'wb') do |file|
          file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=#{graphid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
        end
        FileUtils.mv("/tmp/bugm-sim-graph-#{graphid}", "./#{TS.graph_file_for_webapp_public}all_open_offers.png")
      end
    )
    # Market Metric: price averages of all projects
    threads.push(
      Thread.new do
        graphid="21"
        open("/tmp/bugm-sim-graph-#{graphid}", 'wb') do |file|
          file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=#{graphid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
        end
        FileUtils.mv("/tmp/bugm-sim-graph-#{graphid}", "./#{TS.graph_file_for_webapp_public}all_prices.png")
      end
    )
    # Health Metric: Skills in demand in all projects
    threads.push(
      Thread.new do
        graphid="24"
        open("/tmp/bugm-sim-graph-#{graphid}", 'wb') do |file|
          file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=#{graphid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
        end
        FileUtils.mv("/tmp/bugm-sim-graph-#{graphid}", "./#{TS.graph_file_for_webapp_public}all_skills.png")
      end
    )
    threads.each(&:join)
    # Health Metric: New messages by project
    threads.push(
      Thread.new do
        graphid="26"
        open("/tmp/bugm-sim-graph-#{graphid}", 'wb') do |file|
          file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=#{graphid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
        end
        FileUtils.mv("/tmp/bugm-sim-graph-#{graphid}", "./#{TS.graph_file_for_webapp_public}all_messages.png")
      end
    )
    threads.each(&:join)

    # get detailed graphs for each project
    Tracker.pluck('uuid').shuffle.each do |project_uuid|
      project_name = Tracker.where(uuid: project_uuid).first.name
      # get all pictures for this project at the same time
      threads = []
      # Market Metric: open offer count
      threads.push(
        Thread.new do
          graphid="8"
          open("/tmp/bugm-sim-graph-#{graphid}", 'wb') do |file|
            file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=#{graphid}&var-project_name=#{project_name}&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
          end
          FileUtils.mv("/tmp/bugm-sim-graph-#{graphid}", "./#{TS.graph_file_for_webapp_public}#{project_uuid}_open_offers.png")
        end
      )
      # Market Metric; price ranges of individual projects
      threads.push(
        Thread.new do
          graphid="20"
          open("/tmp/bugm-sim-graph-#{graphid}", 'wb') do |file|
            file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=#{graphid}&var-project_name=#{project_name}&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
          end
          FileUtils.mv("/tmp/bugm-sim-graph-#{graphid}", "./#{TS.graph_file_for_webapp_public}#{project_uuid}_prices.png")
        end
      )
      # Health Metric: Skills in demand
      threads.push(
        Thread.new do
          graphid="23"
          open("/tmp/bugm-sim-graph-#{graphid}", 'wb') do |file|
            file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=#{graphid}&var-project_name=#{project_name}&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
          end
          FileUtils.mv("/tmp/bugm-sim-graph-#{graphid}", "./#{TS.graph_file_for_webapp_public}#{project_uuid}_skills.png")
        end
      )
      # Health Metric: Skills in demand
      threads.push(
        Thread.new do
          graphid="27"
          open("/tmp/bugm-sim-graph-#{graphid}", 'wb') do |file|
            file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=#{graphid}&var-project_name=#{project_name}&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
          end
          FileUtils.mv("/tmp/bugm-sim-graph-#{graphid}", "./#{TS.graph_file_for_webapp_public}#{project_uuid}_messages.png")
        end
      )
      # wait until pictures for this project are stored before going to the next project
      threads.each(&:join)
      # contract fix rate
      # threads.push(
      #   Thread.new do
      #     open('/tmp/bugm-sim-graph-1', 'wb') do |file|
      #       file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=2&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
      #     end
      #     FileUtils.mv('/tmp/bugm-sim-graph-1', "./#{TS.graph_file_for_webapp_public}#{project_uuid}_contract_fix_rate.png")
      #   end
      # )
      # payout vs potential
      # threads.push(
      #   Thread.new do
      #     open('/tmp/bugm-sim-graph-2', 'wb') do |file|
      #       file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=4&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
      #     end
      #     FileUtils.mv('/tmp/bugm-sim-graph-2', "./#{TS.graph_file_for_webapp_public}#{project_uuid}_payout_vs_potential.png")
      #   end
      # )
      # variance of offer volumes
      # threads.push(
      #   Thread.new do
      #     open('/tmp/bugm-sim-graph-3', 'wb') do |file|
      #       file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=6&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
      #     end
      #     FileUtils.mv('/tmp/bugm-sim-graph-3', "./#{TS.graph_file_for_webapp_public}#{project_uuid}_var_offer_volumes.png")
      #   end
      # )
      # # maturation days offers summary
      # threads.push(
      #   Thread.new do
      #     open('/tmp/bugm-sim-graph-5', 'wb') do |file|
      #       file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=10&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i - 60*60*24}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
      #     end
      #     FileUtils.mv('/tmp/bugm-sim-graph-5', "./#{TS.graph_file_for_webapp_public}#{project_uuid}_maturation_days_offer_summary.png")
      #   end
      # )
      # open issues
      # threads.push(
      #   Thread.new do
      #     open('/tmp/bugm-sim-graph-6', 'wb') do |file|
      #       file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=12&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
      #     end
      #     FileUtils.mv('/tmp/bugm-sim-graph-6', "./#{TS.graph_file_for_webapp_public}#{project_uuid}_open_issues.png")
      #   end
      # )
      # # closed issues
      # threads.push(
      #   Thread.new do
      #     open('/tmp/bugm-sim-graph-7', 'wb') do |file|
      #       file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=13&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
      #     end
      #     FileUtils.mv('/tmp/bugm-sim-graph-7', "./#{TS.graph_file_for_webapp_public}#{project_uuid}_closed_issues.png")
      #   end
      # )
      # issue resolution efficiency
      # threads.push(
      #   Thread.new do
      #     open('/tmp/bugm-sim-graph-8', 'wb') do |file|
      #       file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=16&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
      #     end
      #     FileUtils.mv('/tmp/bugm-sim-graph-8', "./#{TS.graph_file_for_webapp_public}#{project_uuid}_issue_resolution_efficiency.png")
      #   end
      # )
      # # open issue age
      # threads.push(
      #   Thread.new do
      #     open('/tmp/bugm-sim-graph-9', 'wb') do |file|
      #       file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=14&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
      #     end
      #     FileUtils.mv('/tmp/bugm-sim-graph-9', "./#{TS.graph_file_for_webapp_public}#{project_uuid}_open_issue_age.png")
      #   end
      # )
      # first response days
      # threads.push(
      #   Thread.new do
      #     open('/tmp/bugm-sim-graph-10', 'wb') do |file|
      #       file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=15&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
      #     end
      #     FileUtils.mv('/tmp/bugm-sim-graph-10', "./#{TS.graph_file_for_webapp_public}#{project_uuid}_first_response_days.png")
      #   end
      # )
      # # issue resolution days
      # threads.push(
      #   Thread.new do
      #     open('/tmp/bugm-sim-graph-11', 'wb') do |file|
      #       file << open("http://127.0.0.1:3030/render/d-solo/Ijarcnomz/test-environment?orgId=1&panelId=17&var-project=#{project_uuid}&from=#{BugmTime.now.to_i - TS.graph_time_window_seconds}000&to=#{BugmTime.now.to_i}000&width=#{@graph_size_width}&height=#{@graph_size_height}&tz=UTC-05%3A00").read
      #     end
      #     FileUtils.mv('/tmp/bugm-sim-graph-11', "./#{TS.graph_file_for_webapp_public}#{project_uuid}_issue_resolution_days.png")
      #   end
      # )
    end

  end

  # ##############################################
  # Simulate Funders
  # ##############################################

  def btn_bot_start_stop(tracker,variant = '')
    # get current status of bot
    sql = "WITH subq AS (SELECT users.jfields->'bot'->>'active' as status2 FROM users
            WHERE jfields->>'tracker' = '#{tracker}')
            SELECT CASE WHEN status2 IS NULL THEN 'false'
            ELSE status2 END AS status
            FROM subq;";
    status = ActiveRecord::Base.connection.execute(sql).to_a
    # binding.pry
    # return appropriate button
    if status[0]['status'].eql? "true" then
      return "<a href='/admin/run_bot#{variant}/#{tracker}' class='btn btn-success'>Active (click to deactivate)</a>"
    else
      return "<a href='/admin/run_bot#{variant}/#{tracker}' class='btn btn-outline-danger'>Inactive (click to activate)</a>"
    end
  end

  def bot_start(tracker)
    sql = "UPDATE users SET jfields = jsonb_set(jfields, '{bot,active}', jsonb '\"true\"')
              WHERE jfields->>'tracker' = '#{tracker.uuid}'";
    ActiveRecord::Base.connection.execute(sql)
  end

  def bot_stop(tracker)
    sql = "UPDATE users SET jfields = jsonb_set(jfields, '{bot,active}', jsonb '\"false\"')
              WHERE jfields->>'tracker' = '#{tracker.uuid}'";
    ActiveRecord::Base.connection.execute(sql)
  end

  def self.bot_stop(tracker)
    sql = "UPDATE users SET jfields = jsonb_set(jfields, '{bot,active}', jsonb '\"false\"')
              WHERE jfields->>'tracker' = '#{tracker.uuid}'";
    ActiveRecord::Base.connection.execute(sql)
  end

  def bot_running?(tracker)
  sql = "WITH subq AS (SELECT users.jfields->'bot'->>'active' as status2 FROM users
          WHERE jfields->>'tracker' = '#{tracker.uuid}')
          SELECT CASE WHEN status2 IS NULL THEN 'false'
          ELSE status2 END AS status
          FROM subq;";
  status = ActiveRecord::Base.connection.execute(sql).to_a
  return status[0]["status"].eql? 'true'
  end


  # Utility function
  def self.difficulty_picker(options)
    # from https://stackoverflow.com/questions/19261061/picking-a-random-option-where-each-option-has-a-different-probability-of-being
    current, max = 0, options.values.inject(:+)
    random_value = rand(max) + 1
    options.each do |key,val|
       current += val
       return key if random_value <= current
    end
  end

  def self.sim_funders
    # get all active bots
    sql = "WITH subq AS (SELECT users.uuid, users.jfields->'bot'->>'active' as status2 FROM users)
          SELECT uuid
          FROM subq
          WHERE status2 = 'true';";
    active_bots = ActiveRecord::Base.connection.execute(sql).to_a
    # simulate each bot
    active_bots.each do |k|
      # get user and tracker
      user = User.where(uuid: k['uuid']).first
      tracker = Tracker.where(uuid: user.jfields['tracker']).first

      puts "----- simulate project: #{tracker.name}"

      # create new offers
      if user.jfields['bot']['newissues'].nil?
        puts "Error executing bot, missing information for project #{tracker.name}"
        return
      end
      newissues = difficulty_picker(user.jfields['bot']['newissues']).to_i
      maxissues = user.jfields['bot']['maxissues'].to_i
      newissues.times do
        break if maxissues <= tracker.issues.open.count
        issue_create(tracker)
      end

      # create new offers
      newoffers = difficulty_picker(user.jfields['bot']['newoffers']).to_i
      prices = user.jfields['bot']['prices']
      volumes = user.jfields['bot']['volumes']
      maturations = user.jfields['bot']['maturations']

      if newoffers.nil? || prices.nil? || newoffers.nil? || volumes.nil? || maturations.nil?
        puts "Error executing bot, missing information for project #{tracker.name}"
        return
      end

      # binding.pry
      newoffers.times do
        # find open issue to use, randomly select an issue
        issue = tracker.issues.open.sample

        # random pick offer parameters
        price = difficulty_picker(prices).to_f
        volume = difficulty_picker(volumes).to_i
        maturation = difficulty_picker(maturations).to_i
        offer_create_bu(user, issue, price, volume, maturation, true)
      end
    end
  end
  #
  # # simulate funder random pay
  # def sim_funder_randompay(user, issue, prices, volumes, durations)
  #   # function being called by simulation for funder to do something
  #
  #   price = difficulty_picker(prices)
  #   volume = difficulty_picker(volumes)
  #   mat_days = difficulty_picker(maturation_days)
  #
  #   # args is a hash
  #   args  = {
  #     user_uuid: user.uuid,
  #     price: price,
  #     volume: volume,
  #     stm_issue_uuid: issue.uuid,
  #     maturation: mat_days
  #   }
  #   offer = FB.create(:offer_bu, args).offer
  #   ContractCmd::Cross.new(offer, :expand).project
  # end

end
