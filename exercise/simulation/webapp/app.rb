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

helpers AppHelpers

# ----- core app -----

get "/" do
  slim :home
end

# ----- project Page -----
get "/project" do
  protected!
  @treatment = current_user["jfields"]["treatment"]
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
get "/issue_generation" do
  slim :issue_generation
end

post "/issue_generation" do
  opts = {
    stm_title: params["issuename"],
    #stm_tracker_uuid: ,
    stm_body: params["issuedetail"],
    #jfields: '{"skill": "Java"}'
  }
  FB.create(:issue, opts).issue
end



# show one issue
get "/issues/:uuid" do
  protected!
  @issue = Issue.find_by_uuid(params['uuid'])
  @comments = Issue_Comment.where(issue_uuid: params['uuid']).where(:comment_delete => nil).order(comment_date: :asc)
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issue_detail','#{params['uuid']}');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :issue
end

# Additing task to queue
post "/issue_task_queue/:uuid" do
  protected!
  # moved logic to app_helper to reuse it in the simulation.
  queue_add_task(current_user.uuid,params['uuid'],params['task'])
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'add_to_queue','#{params['uuid']}');"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/issues/#{params['uuid']}"
end


post "/issue_task_queue_remove/:uuid" do
  protected!
  cancelsql = "SELECT startwork, EXTRACT(EPOCH FROM (completed - startwork))::numeric::integer as full, EXTRACT(EPOCH FROM(completed - current_timestamp))::numeric::integer as partial FROM work_queues WHERE id=#{params["Cancel"]} ;"
  shifts = ActiveRecord::Base.connection.execute(cancelsql).first
  if shifts['partial'] > 2
    cancelsql = "UPDATE work_queues SET removed = now() WHERE id=#{params["Cancel"]} ;"
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
  redirect "/issues/#{params["uuid"]}"
  #slim :accountf
end


# Adding comments to the issue
post "/issue_comments/:uuid" do
  protected!
#  binding.pry
  @issue = Issue.find_by_uuid(params['uuid'])
  issue_comment_sql = "Insert into issue_comments (issue_uuid, user_uuid, user_name, comment, comment_date)
    values ('#{@issue.uuid}', '#{current_user.uuid}', '#{current_user.name}', '#{params["Comments"]}', '#{BugmTime.now.to_s.slice(0..18)}');"
  ActiveRecord::Base.connection.execute(issue_comment_sql)
  issue_update_sql = "update issues
      set jfields = jsonb_set(jfields, '{\"first_activity\"}', jsonb '\"#{BugmTime.now.strftime("%Y-%m-%d")}\"')
      WHERE uuid = '#{@issue.uuid}'
      AND jfields->>'first_activity' = '';"
  ActiveRecord::Base.connection.execute(issue_update_sql)
  issue_update_sql = "update issues
          set jfields = jsonb_set(jfields, '{\"last_activity\"}', jsonb '\"#{BugmTime.now.strftime("%Y-%m-%d")}\"')
          WHERE uuid = '#{@issue.uuid}';"
  ActiveRecord::Base.connection.execute(issue_update_sql)
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issue_comment','#{params['uuid']}');"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/issues/#{params['uuid']}"
end

# Deleting comments of an issue
post "/issue_comments_delete" do
  protected!
#  binding.pry
#  @issue = Issue.find_by_uuid(params['uuid'])
  issue_uuid = Issue_Comment.where(id: params["id"]).first.issue_uuid
  issue_comment_delete_sql = "Update issue_comments
    set comment_delete = '#{BugmTime.now.to_s.slice(0..18)}'
    where id = #{params["id"]} ;"
  ActiveRecord::Base.connection.execute(issue_comment_delete_sql)
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issue_comments_delete','#{issue_uuid}');"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/issues/#{issue_uuid}"
end



# show one issue
get "/issues_ex/:exid" do
  protected!
  issue = Issue.find_by_exid(params['exid'])
  redirect "/issues/#{issue.uuid}"
end

# list all open issues
get "/issues" do
  protected!
  @OpenClosed = "Open"
  @issues = Issue.open
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issues');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :issues
end

# list closed issues
get "/issues_closed" do
  protected!
  @OpenClosed = "Closed"
  @issues = Issue.closed
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'issues_closed');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :issues
end

# render a dynamic SVG for the issues
get '/badge_ex/*' do |issue_exid|
  content_type 'image/svg+xml'
  cache_control :no_cache
  expires 0
  last_modified Time.now
  etag SecureRandom.hex(10)
  @issue = Issue.find_by_exid(issue_exid.split(".").first)
  erb :badge
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
  issue = Issue.find_by_uuid(uuid)
  opts = {
    aon:            params['side'] == 'unfixed' ? true : false ,
    price:          params['side'] == 'unfixed' ? 0.80 : 0.20  ,
    volume:         params['value'].to_i                       ,
    user_uuid:      current_user.uuid,
    maturation:     Time.parse(params['maturation']).change(hour: 23, min: 55),
    expiration:     Time.parse(params['expiration']).change(hour: 23, min: 50),
    poolable:       false,
    stm_issue_uuid: uuid,
    stm_tracker_uuid: issue.stm_tracker_uuid
  }
  if issue
    type = params['side'] == 'unfixed' ? :offer_bu : :offer_bf
    result = FB.create(type, opts).project
    offer = result.offer
    flash[:success] = "You have funded a new offer (#{offer.xid})"
  else
    flash[:danger] = "Something went wrong"
  end
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'create_offer/#{params['side']}','#{uuid}');"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/issues/#{uuid}"
end


# fund an offer
get "/offer_fund/:issue_uuid" do
  protected!
  uuid  = params['issue_uuid']
  issue = Issue.find_by_uuid(uuid)
  opts = {
    price:          0.50,
    volume:         20,
    user_uuid:      current_user.uuid,
    maturation:     BugmTime.end_of_day,
    expiration:     BugmTime.end_of_day,
    poolable:       false,
    stm_issue_uuid: uuid,
    stm_tracker_uuid: issue.stm_tracker_uuid
  }
  if issue
    offer = FB.create(:offer_bu, opts).project.offer
    flash[:success] = "You have funded a new offer (#{offer.xid})"
  else
    flash[:danger] = "Something went wrong"
  end
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'fund_offer/unfixed','#{uuid}');"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/issues/#{uuid}"
end

# accept offer and form a contract
get "/offer_accept/:offer_uuid" do
  protected!
  user_uuid = current_user.uuid
  uuid      = params['offer_uuid']
  offer     = Offer.find_by_uuid(uuid)
  counter   = OfferCmd::CreateCounter.new(offer, poolable: false, user_uuid: user_uuid).project.offer
  contract  = ContractCmd::Cross.new(counter, :expand).project.contract
  flash[:success] = "You have formed a new contract"
  log_sql = "Insert into log (user_uuid, time, page, issue_uuid)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'accept_offer','#{contract.issue.uuid}');"
  ActiveRecord::Base.connection.execute(log_sql)
  redirect "/issues/#{contract.issue.uuid}"
end

# ----- positions -----

get "/positions" do
  protected!
  @sellable = sellable_positions(current_user)
  @buyable  = buyable_positions
  slim :positions
end

post "/position_sell/:position_uuid" do
  protected!
  position = Position.find_by_uuid(params['position_uuid'])
  issue    = position.offer.issue
  value    = params['value'].to_i
  price    = (20 - value) / 20.0
  result   = OfferCmd::CreateSell.new(position, price: price)
  alt = result.project
  flash[:success] = "You have made an offer to sell your position"
  redirect "/issues/#{issue.uuid}"
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
  flash[:success] = "You have formed a new contract"
  redirect "/issues/#{contract.issue.uuid}"
end

# ----- contracts -----

# show one contract
get "/contracts/:uuid" do
  protected!
  @contract = Contract.find_by_uuid(params['uuid'])
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'contract_detail');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :contract
end

# list my contracts
get "/contracts" do
  protected!
  @title     = "My Contracts"
  @contracts = current_user.contracts
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'contracts_my');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :contracts
end

# list all contracts
get "/contracts_all" do
  protected!
  @title     = "All Contracts"
  @contracts = Contract.all
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'contracts_all');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :contracts
end

# ----- user account -----

# funder account
get "/account" do
  protected!
  @work_queues = Work_queue.where(user_uuid: current_user.uuid).where(removed: [nil, ""]).order('startwork')
  log_sql = "Insert into log (user_uuid, time, page)
    values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'account');"
  ActiveRecord::Base.connection.execute(log_sql)
  slim :account
end

# remove work queue item
post "/account" do
  protected!
  cancelsql = "SELECT startwork, EXTRACT(EPOCH FROM (completed - startwork))::numeric::integer as full, EXTRACT(EPOCH FROM(completed - current_timestamp))::numeric::integer as partial FROM work_queues WHERE id=#{params["Cancel"]} ;"
  shifts = ActiveRecord::Base.connection.execute(cancelsql).first
  if shifts['partial'] > 2
    cancelsql = "UPDATE work_queues SET removed = now() WHERE id=#{params["Cancel"]} ;"
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
  redirect "/account"
  #slim :accountf
end


post "/set_username" do
  protected!
  user = current_user
  user.name = params["newName"]
  if user.save
    flash[:success] = "Your new username is '#{params["newName"]}'"
  else
    flash[:danger] = user.errors.messages.values.flatten.join(" ")
  end
  redirect "/account"
end

# ------------ create user account ------------
get "/account_creation" do
  slim :account_creation
end

post "/account_creation" do
  opts = {
    balance: 200,
    name: params["username"],
    email: params["useremail"],
    password:  SecureRandom.hex(2),
    jfields: '{"skill": "Java"}'
  }
  FB.create(:user, opts).user
end

# ----- login/logout -----

get "/login" do
  if current_user
    flash[:danger] = "You are already logged in!"
    redirect back
  else
    slim :login
  end
end

post "/login" do
  mail, pass = [params["usermail"], params["password"]]
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
    redirect path || "/account"
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
    log_sql = "Insert into log (user_uuid, time, page)
      values ('#{current_user.uuid}', '#{BugmTime.now.strftime("%Y-%m-%dT%H:%M:%S")}', 'help/#{@page}');"
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

get "/ytrack/:exid" do
  @navbar = :layout_nav_ytrack
  @exid   = params['exid']
  @issue  = Iora.new(TS.tracker_type, TS.tracker_name).issue(@exid)
  @page   = "issue"
  slim :ytrack
end

get "/ytrack" do
  @navbar = :layout_nav_ytrack
  @page   = "home"
  slim :ytrack
end

get "/ytrack_close/:exid" do
  @exid = params['exid']
  iora = Iora.new(TS.tracker_type, TS.tracker_name)
  issue = iora.issue(@exid)
  iora.close(issue["sequence"])
  flash[:success] = "Issue was closed"
  redirect "/ytrack/#{@exid}"
end

get "/ytrack_open/:exid" do
  @exid = params['exid']
  iora = Iora.new(TS.tracker_type, TS.tracker_name)
  issue = iora.issue(@exid)
  iora.open(issue["sequence"])
  flash[:success] = "Issue was opened"
  redirect "/ytrack/#{@exid}"
end

# ----- admin -----

get "/admin" do
  protected!
  trmt = current_user["jfields"]["treatment"]
  redirect "/account" if trmt == "no-metrics" || trmt == "health-metrics" || trmt == "market-metrics" || trmt == "both-metrics"
  @users = User.all
  @contracts = Contract.open
  @offers = Offer.open
  slim :admin
end


get "/admin/user/:uuid" do
  protected!
  trmt = current_user["jfields"]["treatment"]
  redirect "/account" if trmt == "no-metrics" || trmt == "health-metrics" || trmt == "market-metrics" || trmt == "both-metrics"
  @user = User.where(uuid: params['uuid']).first
  slim :admin_user
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
