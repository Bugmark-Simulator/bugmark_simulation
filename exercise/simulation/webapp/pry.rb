#!/usr/bin/env ruby

Dir.chdir File.expand_path(__dir__)
require_relative '../../Base/lib/dotenv'
TRIAL_DIR = dotenv_trial_dir(__dir__)
require_relative '../../Base/lib/trial_settings'
require File.expand_path("~/src/exchange/config/environment")
binding.pry
puts "Command after pry"
