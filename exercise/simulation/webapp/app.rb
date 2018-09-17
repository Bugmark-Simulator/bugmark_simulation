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
  binding.pry
  slim :home
end

# ----- project Page -----
get "/project" do
  protected!
  @trackers = Tracker.all
  @issue = Issue.all

  sql = "SELECT COUNT(offers.uuid) FROM offers
  JOIN issues ON offers.stm_issue_uuid = issues.uuid
  JOIN trackers ON issues.stm_tracker_uuid = trackers.uuid
  WHERE offers.status = 'open';  "
  openoffer = ActiveRecord::Base.connection.execute(sql).to_a
  @openoffers = openoffer[0]["count"]

  sql1 = "SELECT COUNT(contracts.uuid) FROM contracts
  JOIN issues ON contracts.stm_issue_uuid = issues.uuid
  JOIN trackers ON issues.stm_tracker_uuid = trackers.uuid
  WHERE contracts.status = 'open';  "
  activecontract = ActiveRecord::Base.connection.execute(sql1).to_a
  @activecontract = activecontract[0]["count"]

  slim :project
end


# -----project page include tracker ------
# list all tracker which is project also



# ----- wordquest -----

get "/wordquest/:hexid" do
  protected!
  @hexid  = params["hexid"].upcase
  @issue  = Issue.by_hexid(@hexid).first
  @cwrd   = CodeWord.new
  @issues = @cwrd.issues_for_user(current_user.uuid)
  @kwd    = @cwrd.codeword_for_user(@issue.sequence, current_user.uuid)
  slim :wordquest
end

post "/wordquest/:hexid" do
  protected!
  cwrd = CodeWord.new
  c1, c2 = [params['codeword1'].capitalize, params['codeword2'].capitalize]
  if solution = cwrd.solution_for(c1, c2)
    flash[:solution] = "The solution for: #{c1} + #{c2} = <b>#{solution}</b>"
  else
    flash[:danger] = "No solution was found for / #{c1} / #{c2} /"
  end
  redirect "/wordquest/#{params["hexid"]}"
end

get "/wordquest" do
  protected!
  @issues = CodeWord.new.issues_for_user(current_user.uuid)
  slim :wordquest
end

get "/wordkeys" do
  protected!
  @cwrd = CodeWord.new.issues
  slim :wordkeys
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
  #binding.pry
  slim :issue
end

# Additing task to queue
post "/issue_task_queue/:uuid" do
  protected!
  # moved logic to app_helper to reuse it in the simulation.
  queue_add_task(current_user.uuid,params['uuid'],params['task'])
  # @issue = Issue.find_by_uuid(params['uuid'])
  # datesql = "Select max(completed) from work_queues where user_uuid = '#{current_user.uuid}'
  # and completed > now()
  # and removed IS NULL;"
  # maxdate = ActiveRecord::Base.connection.execute(datesql).to_a
  # #maxdate = JSON.parse(maxdate1)['max']
  # if maxdate[0]["max"].nil?
  #   startdate = 'now()'
  # else
  #  startdate = "(timestamp '#{maxdate[0]["max"]}')"
  # end
  # sql = "INSERT INTO work_queues (user_uuid, issue_uuid, task, added_queue, position, completed, startwork)
  # values ('#{current_user.uuid}','#{@issue.uuid}','#{params["task"]}',
  #   '#{BugmTime.now.to_s.slice(0..18)}', 1, #{startdate} + '1 minute',#{startdate}) ;"
  # ActiveRecord::Base.connection.execute(sql).to_a
  redirect "/issues/#{params['uuid']}"
end

# Adding comments to the issue
post "/issue_comments/:uuid" do
  protected!
#  binding.pry
  @issue = Issue.find_by_uuid(params['uuid'])
  issue_comment_sql = "Insert into issue_comments (issue_uuid, user_uuid, user_name, comment, comment_date)
    values ('#{@issue.uuid}', '#{current_user.uuid}', '#{current_user.name}', '#{params["Comments"]}', '#{BugmTime.now.to_s.slice(0..18)}');"
  ActiveRecord::Base.connection.execute(issue_comment_sql)
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
  redirect "/issues/#{issue_uuid}"
end



# show one issue
get "/issues_ex/:exid" do
  protected!
  issue = Issue.find_by_exid(params['exid'])
  redirect "/issues/#{issue.uuid}"
end

# list all issues
get "/issues" do
  protected!
  @issues = Issue.open
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
  slim :contract
end

# list my contracts
get "/contracts" do
  protected!
  @title     = "My Contracts"
  @contracts = current_user.contracts
  slim :contracts
end

# list all contracts
get "/contracts_all" do
  protected!
  @title     = "All Contracts"
  @contracts = Contract.all
  slim :contracts
end

# ----- user account -----

# account as per dash board
get "/account" do
  protected!
  if current_user["jfields"]["type"] == "funder"
    redirect "/accountf"
  elsif current_user["jfields"]["type"] == "worker"
    redirect "/accountw"
  end
end

# funder account
get "/accountf" do
  protected!
  @work_queues = Work_queue.where(user_uuid: current_user.uuid).where(removed: [nil, ""]).order('startwork')
  slim :accountf
end

post "/accountf" do
  protected!
  cancelsql = "UPDATE work_queues SET removed = now() WHERE id=#{params["Cancel"]} ;"
  ActiveRecord::Base.connection.execute(cancelsql).to_a
  cancelsql = "SELECT startwork, EXTRACT(EPOCH FROM (completed - startwork))::numeric::integer as full, EXTRACT(EPOCH FROM(completed - current_timestamp))::numeric::integer as partial FROM work_queues WHERE id=#{params["Cancel"]} ;"
  shifts = ActiveRecord::Base.connection.execute(cancelsql).first
  if shifts['partial'] > 0
    if shifts['partial'] < shifts['full']
      shift = "'#{shifts['partial']} seconds'"
    elsif
      shift = "'#{shifts['full']} seconds'"
    end
    cancelsql = "UPDATE work_queues SET completed = completed - INTERVAL #{shift}, startwork = startwork - INTERVAL #{shift}
    WHERE startwork > timestamp '#{shifts["startwork"]}' and user_uuid = '#{current_user.uuid}'  ;"
    shifts = ActiveRecord::Base.connection.execute(cancelsql).to_a
  end
  redirect "/accountf"
  #slim :accountf
end

# Worker account
get "/accountw" do
  protected!
  @work_queues = Work_queue.where(user_uuid: current_user.uuid).where(removed: [nil, ""]).order('startwork')
  slim :accountw
end

post "/accountw" do
  protected!
  cancelsql = "UPDATE work_queues SET removed = now() WHERE id=#{params["Cancel"]} ;"
  ActiveRecord::Base.connection.execute(cancelsql).to_a
  cancelsql = "SELECT startwork, EXTRACT(EPOCH FROM (completed - startwork))::numeric::integer as full, EXTRACT(EPOCH FROM(completed - current_timestamp))::numeric::integer as partial FROM work_queues WHERE id=#{params["Cancel"]} ;"
  shifts = ActiveRecord::Base.connection.execute(cancelsql).first
  if shifts['partial'] > 0
    if shifts['partial'] < shifts['full']
      shift = "'#{shifts['partial']} seconds'"
    elsif
      shift = "'#{shifts['full']} seconds'"
    end
    cancelsql = "UPDATE work_queues SET completed = completed - INTERVAL #{shift}, startwork = startwork - INTERVAL #{shift}
    WHERE startwork > timestamp '#{shifts["startwork"]}' and user_uuid = '#{current_user.uuid}'  ;"
    shifts = ActiveRecord::Base.connection.execute(cancelsql).to_a
  end
  redirect "/accountw"
end



#-----account original
# get "/account" do
#   protected!
#   binding.pry
#   #  @events = Event.for_user(current_user)
#   @work_queues = Work_queue.where(user_uuid: current_user.uuid).where(removed: [nil, ""]).order('startwork')
#   slim :account
# end
#
#
# post "/account" do
#   protected!
#   cancelsql = "UPDATE work_queues SET removed = now() WHERE id=#{params["Cancel"]} ;"
#   ActiveRecord::Base.connection.execute(cancelsql).to_a
# #  cancelsql = "SELECT startwork, age(completed, startwork) as full, age(completed,current_timestamp) as partial FROM work_queues WHERE id=#{params["Cancel"]} ;"
#   cancelsql = "SELECT startwork, EXTRACT(EPOCH FROM (completed - startwork))::numeric::integer as full, EXTRACT(EPOCH FROM(completed - current_timestamp))::numeric::integer as partial FROM work_queues WHERE id=#{params["Cancel"]} ;"
#   shifts = ActiveRecord::Base.connection.execute(cancelsql).first
#   # if partial is less than full, shift by partial
#   #try this sql
#   #  SELECT EXTRACT(EPOCH FROM (completed - startwork)), EXTRACT(EPOCH FROM (completed - current_timestamp)) FROM work_queues
#   if shifts['partial'] > 0
#     if shifts['partial'] < shifts['full']
#       shift = "'#{shifts['partial']} seconds'"
#     elsif
#       shift = "'#{shifts['full']} seconds'"
#     end
#     cancelsql = "UPDATE work_queues SET completed = completed - INTERVAL #{shift}, startwork = startwork - INTERVAL #{shift}
#     WHERE startwork > timestamp '#{shifts["startwork"]}' and user_uuid = '#{current_user.uuid}'  ;"
#     shifts = ActiveRecord::Base.connection.execute(cancelsql).to_a
#   end
#   redirect "/account"
# end




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
  slim :help
end

get "/help" do
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
  @users = User.all
  @contracts = Contract.open
  @offers = Offer.open
  slim :admin
end

get "/admin/sync" do
  script = File.expand_path("../script/issue_sync_all", __dir__)
  system script
  flash[:success] = "You have synced the issue tracker"
  redirect '/admin'
end

get "/admin/resolve" do
  script = File.expand_path("../script/contract_resolve", __dir__)
  system script
  flash[:success] = "You have resolved mature contracts"
  redirect '/admin'
end

# ----- coffeescript -----

get "/coffee/*.js" do
  filename = params[:splat].first
  coffee "coffee/#{filename}".to_sym
end



# ----- misc / testing -----

get "/tbd" do
  slim :ztbd
end

get "/ztst" do
  slim :ztst
end
