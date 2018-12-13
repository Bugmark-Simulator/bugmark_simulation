require 'dotenv'

def dotenv_trial_dir(path)
  file = env_file_in_parent(path)
  Dotenv.load(file)
  ENV["TRIAL_DIR"]
end

def dotenv_trial_data(path)
  file = env_file_in_parent(path)
  Dotenv.load(file)
  ENV["TRIAL_DATA"]
end

def dotenv_trial_data_scripts(path)
  dotenv_trial_data(path).split(",")
end

def env_file_in_parent(path)
  base        = File.expand_path("./.env", path)
  parent      = File.expand_path("../.env", path)
  grandparent = File.expand_path("../../.env", path)
  targets = [base, parent, grandparent]
  Dir.glob(targets).first
end
