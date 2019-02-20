# SPDX-License-Identifier: MPL-2.0
require_relative "./lib/web_util"
require_relative "./app_helpers"

require 'sinatra'
require 'sinatra/flash'
require 'sinatra/content_for'

require 'securerandom'

#persing json
require 'rubygems'
require 'json'
require 'chartkick'

set :bind, '0.0.0.0'
set :root, File.dirname(__FILE__)
enable :sessions

$run_nightly = nil
$last_graph_update = nil
$generate_graphs = true
@getting_graph_pictures = false

# Experiment session
$current_session  = nil
$day_of_session = 0
$session_configured = false
$session_wait = false
$session_survey = false
$session_swap_strategy = 0

# record current BugmTime and SystemTime
AppHelpers.record_bugm_system_times

# always
# - check the workqueue
# - check for nightly
# - create graphs
# -
Thread.new do

# TODO: create setting for whether to set bots to off when starting
  # # on init:
  # # get list of running simulations
  # sql = "WITH subq AS (SELECT users.uuid, users.jfields->'bot'->>'active' as status2 FROM users)
  #       SELECT uuid
  #       FROM subq
  #       WHERE status2 = 'true';";
  # active_bots = ActiveRecord::Base.connection.execute(sql).to_a
  # # stop active bots
  # active_bots.each do |k|
  #   AppHelpers.bot_stop(Tracker.where(uuid: User.where(uuid: k['uuid']).first.jfields['tracker']).first)
  # end

  # loop to have asynchronous behavior
  sleep(3)
  loop do
    # sync workqueue
    # Thread.new do
      AppHelpers.workqueue_sync
    # end
    # run nightly script
    # puts "test"
    # puts "check nightly | Value: #{$run_nightly} | Nil: #{(!$run_nightly.nil?)} | Time: #{(!$run_nightly.nil?) && ($run_nightly < Time.now)} "
    if ((!$run_nightly.nil?) && ($run_nightly < Time.now)) then
      puts "=================== SIMULATE NEXT DAY: #{BugmTime.end_of_day(1).strftime("%Y-%m-%d")} ==================="
      $run_nightly += TS.nightly_scr["seconds_for_day_switching"]
      # session day counter
      $day_of_session += 1
      if !$current_session.nil? && $current_session.days_simulated < $day_of_session
        # End of session
        $run_nightly = nil
        $session_survey = true
      end
      Thread.new do
        AppHelpers.next_day
        if !$current_session.nil? && $current_session.bugmtime_start.nil?
          $current_session.update(bugmtime_start: BugmTime.now)
        end
        if !$current_session.nil? && $current_session.days_simulated < $day_of_session
          $current_session.update(bugmtime_end: BugmTime.now)
        end
        $generate_graphs = true
        AppHelpers.sim_funders
      end
    end
    # only get graphs, if the process is not yet running
    # only get graphs if they were requested
    if !@getting_graph_pictures && $generate_graphs then
      # announce that the process is running
      @getting_graph_pictures = true
      # reset requeest bit
      $generate_graphs = false
      puts "=================== UPDATE GRAPHS ==================="
      Thread.new do
        AppHelpers.update_graphs
        $last_graph_update = Time.now
        puts "=================== FINISHED GRAPHS ==================="
        @getting_graph_pictures = false
      end
    end
    # sleep briefly to avoid overloading
    sleep 1
  end
end


helpers AppHelpers

# ----- core app -----

get "/wait" do
  authenticated!
  consented!
  slim :wait
end

get "/questions" do
  authenticated!
  consented!
  slim :survey
end

get "/giftcard" do
  authenticated!
  consented!
  slim :giftcard
end

get "/" do
  if logged_in? then
    redirect "/project"
  else
    slim :home
  end
end

# ----- project Page -----
get "/project" do
  protected!
  @treatment = current_user["jfields"]["treatment"]
  # activity log
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'project');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :project
end




# ----- events -----

get "/events" do
  @events = Event.all
  slim :events
end

get "/events_user/:user_uuid" do
  user = User.find_by_uuid(params['user_uuid'])
  @title  = user.email
  @events = Event.for_user(user)
  slim :events
end

# ----- issues -----

# Generate Issue
# get "/issue_generation" do
#   slim :issue_generation
# end

# post "/issue_generation" do
#   opts = {
#     stm_title: params["issuename"],
#     #stm_tracker_uuid: ,
#     stm_body: params["issuedetail"],
#     #jfields: '{"skill": "Java"}'
#   }
#   FB.create(:issue, opts).issue
# end



# show one issue
get "/issues/:uuid" do
  protected!
  @issue = Issue.find_by_uuid(params['uuid'])
  @comments = Issue_Comment.where(issue_uuid: params['uuid']).where(:comment_delete => nil).order(comment_date: :asc)
  # activity log
  sql_uuid = ActiveRecord::Base.connection.quote(params['uuid'])
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issue_detail',#{sql_uuid});"
  ActiveRecord::Base.connection.execute(log_sql)
  # mark comments on this issue as read
  unread_comments_sql = "DELETE FROM issue_new_comments WHERE issue_uuid = '#{@issue.uuid}' AND user_uuid = '#{current_user.uuid}';"
  ActiveRecord::Base.connection.execute(unread_comments_sql)
  slim :issue
end

# Additing task to queue
post "/issue_task_queue/:uuid" do
  protected!
  # moved logic to app_helper to reuse it in the simulation.
  queue_add_task(current_user.uuid,params['uuid'],params['task'])
  # activity log
  sql_uuid = ActiveRecord::Base.connection.quote(params['uuid'])
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'add_to_queue',#{sql_uuid});"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/issues/#{params['uuid']}"
end


post "/issue_task_queue_remove/:uuid" do
  protected!
  queue_id = params["Cancel"].to_i
  queue_remove_task(queue_id)
  # activity log
  sql_uuid = ActiveRecord::Base.connection.quote(params['uuid'])
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issue_task_queue_remove',#{sql_uuid});"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/issues/#{params["uuid"]}"
  #slim :accountf
end


# Adding comments to the issue
post "/issue_comments/:uuid" do
  protected!
  @issue = Issue.find_by_uuid(params['uuid'])
  # write comment
  sql_comment = ActiveRecord::Base.connection.quote(params['Comments'])
  issue_comment_sql = "Insert into issue_comments (issue_uuid, user_uuid, user_name, comment, comment_date)
    values ('#{@issue.uuid}', '#{current_user.uuid}', '#{user_name(current_user)}', #{sql_comment}, '#{BugmTime.now.to_s.slice(0..18)}');"
  ActiveRecord::Base.connection.execute(issue_comment_sql)
  # update first activity on issue, if not set yet
  issue_update_sql = "update issues
      set jfields = jsonb_set(jfields, '{\"first_activity\"}', jsonb '\"#{BugmTime.now.strftime("%Y-%m-%d")}\"')
      WHERE uuid = '#{@issue.uuid}'
      AND jfields->>'first_activity' = '';"
  ActiveRecord::Base.connection.execute(issue_update_sql)
  # update last activity on issue
  issue_update_sql = "update issues
          set jfields = jsonb_set(jfields, '{\"last_activity\"}', jsonb '\"#{BugmTime.now.strftime("%Y-%m-%d")}\"')
          WHERE uuid = '#{@issue.uuid}';"
  ActiveRecord::Base.connection.execute(issue_update_sql)
  # record that an unread comment exists
  unread_comments_sql = "Insert into issue_new_comments (issue_uuid, user_uuid, new_comments)
    SELECT '#{@issue.uuid}', users.uuid, '1'
    FROM users
    ON CONFLICT (issue_uuid, user_uuid) DO
    UPDATE SET new_comments = issue_new_comments.new_comments + 1;"
  ActiveRecord::Base.connection.execute(unread_comments_sql)
  # activity log
  sql_uuid = ActiveRecord::Base.connection.quote(params['uuid'])
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issue_comment',#{sql_uuid});"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/issues/#{params['uuid']}"
end

# Deleting comments of an issue
# post "/issue_comments_delete" do
#   protected!
# #  binding.pry
# #  @issue = Issue.find_by_uuid(params['uuid'])
#   issue_uuid = Issue_Comment.where(id: params["id"]).first.issue_uuid
#   sql_id = ActiveRecord::Base.connection.quote(params['id'])
#   issue_comment_delete_sql = "Update issue_comments
#     set comment_delete = '#{BugmTime.now.to_s.slice(0..18)}'
#     where id = #{params["sql_id"]} ;"
#   ActiveRecord::Base.connection.execute(issue_comment_delete_sql)
#   # activity log
#   sql_uuid = ActiveRecord::Base.connection.quote(params['uuid'])
#   log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
#     values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issue_comments_delete',#{sql_uuid});"
#   ActiveRecord::Base.connection.execute(log_sql)
#   redirect "/issues/#{issue_uuid}"
# end



# show one issue
# get "/issues_ex/:exid" do
#   protected!
#   issue = Issue.find_by_exid(params['exid'])
#   redirect "/issues/#{issue.uuid}"
# end

# list of open  issues for a specific project
get "/project_issues" do
  protected!
  if session[:project_issues] then
    project = Tracker.where(uuid: session[:project_issues]).first
    redirect "/project_issues/#{project.uuid}"
  else
    redirect "/project_issues/#{Tracker.first.uuid}"
  end
end

# list of open issues for a specific project
get "/project_issues/:uuid" do
  protected!
  @project = Tracker.where(uuid: params['uuid']).first
  session[:project_issues] = @project.uuid
  @OpenClosed = "Open"
  @issues = Issue.where(stm_tracker_uuid: @project.uuid).open
  # activity log
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issues');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :project_issues
end

# list of closed issues for a specific project
get "/project_issues_closed" do
  protected!
  if session[:project_issues] then
    project = Tracker.where(uuid: session[:project_issues]).first
    redirect "/project_issues_closed/#{project.uuid}"
  else
    redirect "/issues_closed"
  end
end

# list of closed issues for a specific project
get "/project_issues_closed/:uuid" do
  protected!
  @project = Tracker.where(uuid: params['uuid']).first
  session[:project_issues] = @project.uuid
  @OpenClosed = "Closed"
  @issues = Issue.where(stm_tracker_uuid: @project.uuid).closed
  # activity log
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issues');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :project_issues
end


# list all open issues
get "/issues" do
  protected!
  # @OpenClosed = "Open"
  # @issues = Issue.open
  # # activity log
  # log_sql = "Insert into log (user_uuid, time, page)
  #   values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issues');"
  # ActiveRecord::Base.connection.execute(log_sql)
  # slim :issues

  # remove a universal issues tracker
  redirect "/project_issues"
end

# list closed issues
get "/issues_closed" do
  protected!
  @OpenClosed = "Closed"
  @issues = Issue.closed
  # activity log
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issues_closed');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :issues
end


# ----- offers -----

# show one offer
get "/offers/:uuid" do
  protected!
  @offer = Offer.find_by_uuid(params['uuid'])
  slim :offer
end

# list all offers
get "/offers" do
  protected!
  @offers = Offer.open.with_issue.all
  slim :offers
end

# cancel an offer
get "/offer_cancel/:offer_uuid" do
  offer = Offer.find_by_uuid(params['offer_uuid'])
  issue = offer.issue
  OfferCmd::Cancel.new(offer).project
  flash[:success] = "Offer was cancelled"
  redirect "/issues/#{issue.uuid}"
end

# create an offer
post "/offer_create/:issue_uuid" do
  protected!
  uuid  = params['issue_uuid']
  # activity log
  sql_uuid = ActiveRecord::Base.connection.quote(uuid)
  sql_side = ActiveRecord::Base.connection.quote("create_offer/#{params['side']}")
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
  values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', #{sql_side} ,#{sql_uuid});"
  ActiveRecord::Base.connection.execute(log_sql)
  # do stuff
  issue = Issue.find_by_uuid(uuid)
  volume = params['value'].to_i
  price = params['side'] == 'unfixed' ? 0.80 : 0.20
  type = params['side'] == 'unfixed' ? :offer_bu : :offer_bf
  maturation = params['maturation'] ? params['maturation'] : BugmTime.end_of_day(4)

  cost_of_offer = (volume * price).to_i
  if current_user.balance.to_i < cost_of_offer then
    flash[:warning] = "You needed #{cost_of_offer} tokens to create this offer but only have #{current_user.balance.to_i} tokens."
  else
    opts = {
      aon:            true,
      price:          price,
      volume:         volume,
      user_uuid:      current_user.uuid,
      maturation:     Time.parse(maturation).change(hour: 23, min: 55),
      expiration:     Time.parse(maturation).change(hour: 23, min: 50),
      poolable:       false,
      stm_issue_uuid: uuid,
      stm_tracker_uuid: issue.stm_tracker_uuid
    }
    if issue
      offer = FB.create(type, opts).project.offer
      ContractCmd::Cross.new(offer, :expand).project
      flash[:success] = "You successfully created a new offer"
    else
      flash[:danger] = "Something went wrong"
    end
  end
  redirect "/issues/#{uuid}"
end


# fund an offer
# get "/offer_fund/:issue_uuid" do
#   protected!
#   uuid  = params['issue_uuid']
#   issue = Issue.find_by_uuid(uuid)
#   opts = {
#     aon:            true,
#     price:          0.50,
#     volume:         20,
#     user_uuid:      current_user.uuid,
#     maturation:     BugmTime.end_of_day,
#     expiration:     BugmTime.end_of_day,
#     poolable:       false,
#     stm_issue_uuid: uuid,
#     stm_tracker_uuid: issue.stm_tracker_uuid
#   }
#   if issue
#     offer = FB.create(:offer_bu, opts).project.offer
#     ContractCmd::Cross.new(offer, :expand).project
#     flash[:success] = "You have funded a new offer (#{offer.xid})"
#   else
#     flash[:danger] = "Something went wrong"
#   end
#   # activity log
#   sql_uuid = ActiveRecord::Base.connection.quote(uuid)
#   log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
#     values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'fund_offer/unfixed',#{sql_uuid});"
#   ActiveRecord::Base.connection.execute(log_sql)
#   redirect "/issues/#{uuid}"
# end

# accept offer and form a contract
get "/offer_accept/:offer_uuid" do
  protected!
  user_uuid = current_user.uuid
  uuid      = params['offer_uuid']
  offer     = Offer.find_by_uuid(uuid)
  # activity log
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
  values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'accept_offer','#{offer.stm_issue_uuid}');"
  ActiveRecord::Base.connection.execute(log_sql)
  # do page stuff
  cost_to_accept = offer.volume.to_i - offer.value.to_i
  if current_user.balance.to_i < cost_to_accept.to_i then
    flash[:warning] = "You needed #{cost_to_accept} tokens to accept offer but only have #{current_user.balance.to_i} tokens."
    redirect "/issues/#{offer.stm_issue_uuid}"
  elsif offer.status == "crossed"
    flash[:warning] = "Failed because someone else had already accepted that offer"
    redirect "/issues/#{offer.stm_issue_uuid}"
  elsif offer.status == "cancelled"
    flash[:warning] = "Failed because offer was withdrawn"
    redirect "/issues/#{offer.stm_issue_uuid}"
  elsif offer.status == "expired"
    flash[:warning] = "Failed because offer expired"
    redirect "/issues/#{offer.stm_issue_uuid}"
  else
    counter   = OfferCmd::CreateCounter.new(offer, poolable: false, user_uuid: user_uuid).project.offer
    contract  = ContractCmd::Cross.new(counter, :expand).project
    if contract.nil?
      flash[:warning] = "Could not accept offer"
    else
      flash[:success] = "You have accepted an offer"
    end
    redirect "/issues/#{offer.stm_issue_uuid}"
  end
end

# ----- positions -----

# get "/positions" do
#   protected!
#   @sellable = sellable_positions(current_user)
#   @buyable  = buyable_positions
#   slim :positions
# end

post "/position_sell/:position_uuid" do
  protected!
  position = Position.find_by_uuid(params['position_uuid'])
  if position.nil?
    flash[:warning] = 'Error, could not identify the position to sell'
    # activity log
    log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'position_sell/failed');"
    ActiveRecord::Base.connection.execute(log_sql)
    redirect "/issues"
  else
    issue    = position.offer.issue
    value    = params['value'].to_i.to_f
    price    = (position.volume.to_f - value) / position.volume.to_f
    result   = OfferCmd::CreateSell.new(position, price: price)
    alt = result.project
    if alt.nil?
      flash[:warning] = "could not create sale offer"
    else
      flash[:success] = "You have made an offer to sell your position"
    end
    # activity log
    sql_uuid = ActiveRecord::Base.connection.quote(issue.uuid)
    log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'position_sell', #{sql_uuid});"
    ActiveRecord::Base.connection.execute(log_sql)
    redirect "/issues/#{issue.uuid}"
  end
end

get "/position_buy/:offer_uuid" do
  protected!
  user_uuid = current_user.uuid
  uuid      = params['offer_uuid']
  offer     = Offer.find_by_uuid(uuid)
  binding.pry
  result    = OfferCmd::CreateCounter.new(offer, poolable: false, user_uuid: user_uuid)
  counter   = result.project.offer
  binding.pry
  obj       = ContractCmd::Cross.new(counter, :transfer)
  contract  = obj.project.contract
  binding.pry
  flash[:success] = "You have accepted an offer"
  # activity log
  sql_uuid = ActiveRecord::Base.connection.quote(contract.issue.uuid)
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
  values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'position_buy', #{sql_uuid});"
  redirect "/issues/#{contract.issue.uuid}"
end

# ----- contracts -----

# show one contract
get "/contracts/:uuid" do
  protected!
  @contract = Contract.find_by_uuid(params['uuid'])
  # activity log
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'contract_detail');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :contract
end

# list my contracts
get "/contracts" do
  protected!
  @title     = "My Accepted Offers"
  @contracts = current_user.contracts
  # activity log
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'contracts_my');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :contracts
end

# list all contracts
get "/contracts_all" do
  protected!
  @title     = "All Accepted Offers"
  @contracts = Contract.all
  # activity log
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'contracts_all');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :contracts
end

# ----- user account -----

# funder account
get "/account" do
  protected!
  @work_queues = Work_queue.where(user_uuid: current_user.uuid).where(removed: [nil, ""]).where("completed > localtimestamp").order('startwork')
  # activity log
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'account');"
  ActiveRecord::Base.connection.execute(log_sql)
  # best list
  unless $current_session.nil?
    sql = "SELECT name, jfields->'sessions'->'s#{$current_session.id}'->>'earned' as earned FROM users
    WHERE jfields->'sessions'->'s#{$current_session.id}' IS NOT NULL
    ORDER by earned DESC
    LIMIT 10;"
    @best_list = ActiveRecord::Base.connection.execute(sql).to_a
  end

  slim :account
end

# remove work queue item
post "/account" do
  protected!
  sql_cancel_id = ActiveRecord::Base.connection.quote(params["Cancel"])
  cancelsql = "SELECT startwork, EXTRACT(EPOCH FROM (completed - startwork))::numeric::integer as full, EXTRACT(EPOCH FROM(completed - current_timestamp))::numeric::integer as partial FROM work_queues WHERE id=#{sql_cancel_id} ;"
  shifts = ActiveRecord::Base.connection.execute(cancelsql).first
  if shifts['partial'] > 2
    cancelsql = "UPDATE work_queues SET removed = now() WHERE id=#{sql_cancel_id} ;"
    ActiveRecord::Base.connection.execute(cancelsql).to_a
    if shifts['partial'] < shifts['full']
      shift = "'#{shifts['partial']} seconds'"
    elsif
      shift = "'#{shifts['full']} seconds'"
    end
    cancelsql = "UPDATE work_queues SET completed = completed - INTERVAL #{shift}, startwork = startwork - INTERVAL #{shift}
    WHERE startwork > timestamp '#{shifts["startwork"]}' and user_uuid = '#{current_user.uuid}'  ;"
    shifts = ActiveRecord::Base.connection.execute(cancelsql).to_a
  end
  # activity log
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'account/remove_queue_item');"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/account"
  #slim :accountf
end


post "/set_username" do
  authenticated!
  user = current_user
  user.name = params["newName"]
  if user.save
    flash[:success] = "Your new username is '#{params["newName"]}'"
  else
    flash[:danger] = user.errors.messages.values.flatten.join(" ")
  end
  # activity log
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'account/set_username');"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/account"
end

post "/set_password" do
  authenticated!
  user = current_user
  new_password = ActiveRecord::Base.connection.quote(params['newPassword'])
  user.password = new_password
  if user.save
    flash[:success] = "Changed Password, please login again"
    # update last activity on issue
    issue_update_sql = "update users
            set jfields = jsonb_set(jfields, '{\"password\"}', jsonb #{new_password})
            WHERE uuid = '#{current_user.uuid}';"
    ActiveRecord::Base.connection.execute(issue_update_sql) unless user.email == "admin@bugmark.net"
    redirect "logout"
  else
    flash[:danger] = user.errors.messages.values.flatten.join(" ")
  end
  # activity log
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'account/set_password');"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/account"
end

# ------------ create user account ------------
# get "/account_creation" do
#   slim :account_creation
# end

# post "/account_creation" do
#   opts = {
#     balance: 200,
#     name: params["username"],
#     email: params["useremail"],
#     password:  SecureRandom.hex(2),
#     jfields: '{"skill": "Java"}'
#   }
#   FB.create(:user, opts).user
# end

# ----- login/logout -----

get "/login" do
  if current_user
    flash[:danger] = "You are already logged in!"
    redirect "/project"
  else
    slim :login
  end
end

post "/login" do
  mail = params["usermail"]
  pass = params["password"]
  user = User.find_by_email(mail) || User.find_by_name(mail)
  valid_auth    = user && user.valid_password?(pass)
  valid_consent = valid_consent(user)
  case
  when valid_auth && valid_consent
    session[:usermail] = user.email
    session[:consent]  = true
    flash[:success]    = "Logged in successfully"
    AccessLog.new(current_user&.email).logged_in
    path = session[:tgt_path]
    session[:tgt_path] = nil
    log_sql = "Insert into log (user_uuid, time, page)
      values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'login');"
    ActiveRecord::Base.connection.execute(log_sql)
    redirect path || "/admin"
    redirect path || "/project"
  when ! user
    word = (/@/ =~ params["usermail"]) ? "Email Address" : "Username"
    flash[:danger] = "Unrecognized #{word} (#{params["usermail"]}) please try again or contact Georg Link - glink@unomaha.edu"
    redirect "/login"
  when ! valid_auth
    flash[:danger] = "Invalid password - please try again or contact Georg Link - glink@unomaha.edu"
    redirect "/login"
  when ! valid_consent
    session[:usermail] = mail
    AccessLog.new(current_user&.email).logged_in
    redirect "/consent_form"
  end
end

get "/logout" do
  if logged_in?
    log_sql = "Insert into log (user_uuid, time, page)
      values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'logout');"
    ActiveRecord::Base.connection.execute(log_sql)
  end
  session[:usermail] = nil
  session[:consent] = nil
  flash[:warning] = "Logged out"
  redirect "/"
end

# ----- consent -----

get "/consent_form" do
  authenticated!
  slim :consent
end

get "/consent_register" do
  authenticated!
  AccessLog.new(current_user&.email).consented
  session[:consent] = true
  path = session[:tgt_path]
  session[:tgt_path] = nil
  redirect path || "/account"
end

# ----- help -----

get "/help/:page" do
  @page = params['page']
  if logged_in?
    sql_page = ActiveRecord::Base.connection.quote("help/#{@page}")
    log_sql = "Insert into log (user_uuid, time, page)
      values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', #{sql_page});"
    ActiveRecord::Base.connection.execute(log_sql)
  end
  slim :help
end

get "/help" do
  if logged_in?
    log_sql = "Insert into log (user_uuid, time, page)
      values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'help/base');"
    ActiveRecord::Base.connection.execute(log_sql)
  end
  @page = "base"
  slim :help
end

# ----- ytrack issue tracker -----

# get "/ytrack/:exid" do
#   @navbar = :layout_nav_ytrack
#   @exid   = params['exid']
#   @issue  = Iora.new(TS.tracker_type, TS.tracker_name).issue(@exid)
#   @page   = "issue"
#   slim :ytrack
# end
#
# get "/ytrack" do
#   @navbar = :layout_nav_ytrack
#   @page   = "home"
#   slim :ytrack
# end
#
# get "/ytrack_close/:exid" do
#   @exid = params['exid']
#   iora = Iora.new(TS.tracker_type, TS.tracker_name)
#   issue = iora.issue(@exid)
#   iora.close(issue["sequence"])
#   flash[:success] = "Issue was closed"
#   redirect "/ytrack/#{@exid}"
# end
#
# get "/ytrack_open/:exid" do
#   @exid = params['exid']
#   iora = Iora.new(TS.tracker_type, TS.tracker_name)
#   issue = iora.issue(@exid)
#   iora.open(issue["sequence"])
#   flash[:success] = "Issue was opened"
#   redirect "/ytrack/#{@exid}"
# end

# ----- admin -----

get "/admin" do
  admin_only!
  slim :admin
end


get "/admin/users" do
  admin_only!

  @title = "Users Administration"
  @users = User.all
  slim :admin_users
end


get "/admin/user/:uuid" do
  admin_only!

  @user = User.where(uuid: params['uuid']).first
  slim :admin_user
end

post "/admin/users_create" do
  admin_only!
  numnew = params["numnew"].to_i
  treatment = params["treatment"].to_i
  type = params["type"].to_i
  bonuses = params["bonuses"].to_i
  maluses = params["maluses"].to_i
  balance = params["balance"].to_i
  treatments = ["both-metrics", "market-metrics", "health-metrics", "no-metrics"]
  types = ["worker", "funder"]

  # create new users
  numnew.times do
    username= SecureRandom.hex(2)
    emailaddr = username+'@example.com'
    userpassword = SecureRandom.hex(2)
    # nice user name
    if User.count < TS.usernames.count then
      TS.usernames.shuffle.each do |potential_name|
        potential_name = potential_name.gsub(/[^0-9a-zA-Z]/i, '')
        if User.where(name: potential_name).count == 0 then
          username = potential_name
          break
        end
      end
    end
    opts = {
      balance: balance,
      name: username,
      email: emailaddr,
      password: userpassword
    }
    userid = FB.create(:user, opts).user.id
    # update user jfields through sql
    skills = TS.skills["task_skills"].shuffle
    bonus_skills = skills.pop(bonuses)
    malus_skills = skills.pop(maluses)
    json = {}
    json["skill_bonus"] = bonus_skills
    json["skill_malus"] = malus_skills
    json["password"] = userpassword
    json["type"] = types[type]
    json["treatment"] = treatments[treatment]
    json["tracker"] = {}
    json["sessions"] = {}
    sql_json = ActiveRecord::Base.connection.quote(JSON.generate(json))
    # update json in user
    sql = "UPDATE users SET jfields = #{sql_json} WHERE id='#{userid}';"
    ActiveRecord::Base.connection.execute(sql).to_a

    # funders get assigned a tracker and simulation bot
    if(types[type]=='funder') then
      tracker = ""
      # find a sensible projectname
      trackername = SecureRandom.hex(2)
      if Tracker.count < TS.projectnames.count then
        TS.projectnames.shuffle.each do |potential_name|
          if Tracker.where(name: potential_name).count == 0 then
            trackername = potential_name
            break
          end
        end
      end
      # generate a new tracker
      opts = {
        type: "Tracker::Test",
        name: "#{trackername}"
      }
      tracker = FB.create(:tracker, opts).tracker.uuid


      sql = "UPDATE users SET jfields = jsonb_set(jfields, '{bot}', jsonb '{\"active\":\"false\", \"prices\":{\"0.80\":20, \"0.85\":40, \"0.90\":30, \"0.95\":8, \"1.00\":2}, \"volumes\":{\"70\":10, \"80\":30, \"90\":40, \"100\":20}, \"maxissues\":9, \"newissues\":{\"9\":1, \"1\":0}, \"newoffers\":{\"5\":1}, \"maturations\":{\"1\":20, \"2\":20, \"4\":20, \"6\":20, \"8\":20}}') WHERE id='#{userid}';"
      ActiveRecord::Base.connection.execute(sql).to_a
      sql = "UPDATE users SET jfields = jsonb_set(jfields, '{tracker}', '\"#{tracker}\"') WHERE id='#{userid}';"
      ActiveRecord::Base.connection.execute(sql).to_a
    end
    puts "new user: #{username} (#{userid})"
  end
  @title = "New Users"
  @users = User.last(numnew)
  slim :admin_users
end

get "/admin/startstopnighlty" do
  admin_only!
  # binding.pry
  if $run_nightly.nil?
    $run_nightly = Time.now
    puts "=================== STARTING SIMULATION ==================="
    sleep(1.5)
  else
    $run_nightly = nil
    puts "=================== STOPPING SIMULATION ==================="
  end
  # binding.pry
  redirect '/admin'
end

get "/admin/nextday" do
  admin_only!
  puts "=================== MANUAL NEXT DAY ==================="
  unless $run_nightly.nil?
    # if simulation is running, reset clock
    $run_nightly = Time.now
    sleep(1.5)
  else
    # run manually
    AppHelpers.next_day
    $generate_graphs = true
  end
  redirect '/admin'
end
get "/admin/draw_graphs" do
  admin_only!
  $generate_graphs = true
  redirect '/admin'
end

get "/admin/login_as/:uuid" do
  # admin_only!
  user = User.where(uuid: params['uuid']).first
  if user.nil?
    flash[:info] = "Please login"
    redirect '/login'
  end
  session[:usermail] = user.email
  session[:consent]  = true
  redirect '/admin'
end


get "/admin/bot/:uuid" do
  admin_only!
  @tracker = Tracker.where(uuid: params['uuid']).first
  @user = User.where("jfields->>'tracker' = '#{@tracker.uuid}'").first
  if session[:tmp_json]
    @botsettings = session[:tmp_json]
    session[:tmp_json] = nil
  else
    @botsettings = @user.jfields['bot'].to_yaml
  end
  # binding.pry
  @botsettings = @botsettings
  slim :admin_bot
end

post "/admin/bot/:uuid" do
  admin_only!
  tracker = Tracker.where(uuid: params['uuid']).first
  user = User.where("jfields->>'tracker' = '#{tracker.uuid}'").first
  json = params['botsettings']
  # binding.pry
  # make sure json is valid
  if valid_yaml?(json) then
    # escape user input for sql
    sql_json = ActiveRecord::Base.connection.quote(JSON.generate(YAML.load(json)))
    # update json in user
    sql = "UPDATE users SET jfields = jsonb_set(jfields, '{bot}', jsonb #{sql_json}) WHERE id = #{user.id};"
    ActiveRecord::Base.connection.execute(sql)
    # output success message
    flash[:success] = "Saved bot settings for project #{tracker.name}"
  else
    # output error message
    flash[:warning] = "Invalid YAML"
    session[:tmp_json] = json
  end
  redirect "/admin/bot/#{tracker.uuid}"
end

get "/admin/run_bot/:uuid" do
  admin_only!
  if params['uuid'] == "all"
    tracker = Tracker.all
  else
    tracker = Tracker.where(uuid: params['uuid'])
  end
  # change status
  tracker.each do |t|
    if bot_running?(t) then
      bot_stop(t)
    else
      bot_start(t)
    end
  end
  redirect '/admin'
end

get "/admin/stop_bot/:uuid" do
  admin_only!
  if params['uuid'] == "all"
    tracker = Tracker.all
  else
    tracker = Tracker.where(uuid: params['uuid'])
  end
  # change status
  tracker.each do |t|
    bot_stop(t)
  end
  redirect '/admin'
end

get "/admin/start_bot/:uuid" do
  admin_only!
  if params['uuid'] == "all"
    tracker = Tracker.all
  else
    tracker = Tracker.where(uuid: params['uuid'])
  end
  # change status
  tracker.each do |t|
    bot_start(t)
  end
  redirect '/admin'
end

get "/admin/run_bot/:uuid" do
  admin_only!
  tracker = Tracker.where(uuid: params['uuid']).first
   # change status
   if bot_running?(tracker) then
     bot_stop(tracker)
   else
     bot_start(tracker)
   end
  redirect '/admin'
end

# same as above, but redirect to Bot Settings page
get "/admin/run_bot2/:uuid" do
  admin_only!
  tracker = Tracker.where(uuid: params['uuid']).first
  # change status
  if bot_running?(tracker) then
    bot_stop(tracker)
  else
    bot_start(tracker)
  end
  redirect "/admin/bot/#{tracker.uuid}"
end

get "/admin/issue_new/:uuid" do
  admin_only!
  tracker = Tracker.where(uuid: params["uuid"]).first
  AppHelpers.issue_create(tracker)
  flash[:success] = "One issue created for project #{tracker.name}"
  redirect "/admin"
end

get "/admin/issue_new/:uuid/:count" do
  admin_only!
  tracker = Tracker.where(uuid: params["uuid"]).first
  count = params["count"].to_i
  count.times do
    AppHelpers.issue_create(tracker)
  end
  flash[:success] = "#{count} issues created for project #{tracker.name}"
  redirect "/admin"
end

post "/admin/session/create" do
  admin_only!
  num_days = params['daysinsession'].to_i
  $current_session = Session.create(days_simulated: num_days, systime_start: Time.now)
  $day_of_session = 0
  $session_wait = true
  $session_configured = false
  $session_swap_strategy = 0
  # reset market place
  advance_days = [(Offer.maximum('expiration').to_i - BugmTime.now.to_i)/60/60/24 +1, 1].max
  advance_days.times do
    # by getting the max offer expiration, we also get max contract maturation
    AppHelpers.next_day
  end
  Issue.open.each do |issue|
    IssueCmd::Sync.new({exid: issue.exid, stm_status: "closed"}).project
    issue_update_sql = "update issues
            set jfields = jsonb_set(jfields, '{\"closed_on\"}', jsonb '\"#{BugmTime.now.strftime("%Y-%m-%d")}\"')
            WHERE exid = '#{issue.exid}';"
    ActiveRecord::Base.connection.execute(issue_update_sql)
  end
  # TODO: reset funder budgets, to make sure they have deep pockets
  redirect '/admin'
end

post "/admin/session/strategy" do
  admin_only!
  participants = params['participantcount'].to_i
  # calculate new values
  issue_count = (0.75 * participants.to_f).ceil
  offer_count = (0.5 * participants.to_f).ceil
  # update bots
  Tracker.all.each do |tracker|
    user = User.where("jfields->>'tracker' = '#{tracker.uuid}'").first
    user.update(balance: TS.session["funder_balance"])
    json = user.jfields["bot"]
    json["maxissues"] = issue_count
    json["newissues"] = {"#{issue_count}": 1}
    json["newoffers"] = {"#{offer_count}": 1}
    sql_json = ActiveRecord::Base.connection.quote(JSON.generate(json))
    # update json in user
    sql = "UPDATE users SET jfields = jsonb_set(jfields, '{bot}', jsonb #{sql_json}) WHERE id = #{user.id};"
    ActiveRecord::Base.connection.execute(sql)
  end
  $session_configured = true
  redirect '/admin'
end

get "/admin/session/start" do
  admin_only!
  # simulate two days before starting
  days = 2 # TODO: make setting variable
  days.times do
    AppHelpers.sim_funders
    AppHelpers.next_day
  end
  $session_wait = false
  # $current_session.update(bugmtime_start: BugmTime.now)
  $run_nightly = Time.now
  redirect '/admin'
end

get "/admin/session/survey" do
  admin_only!
  redirect '/admin' if $session_survey
  $run_nightly = nil
  $current_session.update(bugmtime_end: BugmTime.now)
  $session_wait = false
  $session_survey = true
  redirect '/admin'
end

get "/admin/session/stop" do
  admin_only!
  $run_nightly = nil
  $session_wait = false
  $session_survey = false
  $current_session.update(bugmtime_end: BugmTime.now) if $current_session.bugmtime_end.nil?
  $current_session.update(systime_end: Time.now)
  # update user balances one last time
  User.all.each do |user|
    if user.id > 1 && !user.jfields["sessions"].nil? && !user.jfields["sessions"]["s#{$current_session.id}"].nil?
      json = user.balance.to_i - TS.session["worker_balance"]
      sql_json = ActiveRecord::Base.connection.quote(JSON.generate(json))
      # update json in user
      sql = "UPDATE users SET jfields = jsonb_set(jfields, '{sessions, s#{$current_session.id}, earned}', jsonb #{sql_json}) WHERE id = #{user.id};"
      ActiveRecord::Base.connection.execute(sql)
    end
  end
  $current_session = nil
  $session_configured = false
  redirect '/admin'
end

# get "/admin/sync" do
#   script = File.expand_path("../script/issue_sync_all", __dir__)
#   system script
#   flash[:success] = "You have synced the issue tracker"
#   redirect '/admin'
# end

# get "/admin/resolve" do
#   script = File.expand_path("../script/contract_resolve", __dir__)
#   system script
#   flash[:success] = "You have resolved mature contracts"
#   redirect '/admin'
# end

# ----- coffeescript -----

get "/coffee/*.js" do
  filename = params[:splat].first
  coffee "coffee/#{filename}".to_sym
end

# don't freak out when a url is not defined:
get '*' do
  redirect '/'
end
post '*' do
  redirect '/'
end
put '*' do
  redirect '/'
end
delete '*' do
  redirect '/'
end
