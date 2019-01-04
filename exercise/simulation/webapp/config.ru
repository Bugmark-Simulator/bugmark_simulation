# SPDX-License-Identifier: MPL-2.0

# require_relative '../../Base/lib/base'

require_relative '../../Base/lib/exchange'

Exchange.load_rails

require_relative "./app"

run Sinatra::Application
