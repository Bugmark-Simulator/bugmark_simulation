# require_relative '../../Base/lib/base'
#
require_relative '../../Base/lib/exchange'

Exchange.load_rails

require_relative "./app"

run Sinatra::Application
