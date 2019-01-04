# SPDX-License-Identifier: MPL-2.0
require_relative './string_ext'
require 'yaml'

class AccessLog

  attr_reader :email, :cmail
  attr_accessor :log_data

  def initialize(email)
    @email    = email
    @cmail    = email&.alt_encrypt
    @log_data = File.exists?(log_file) ? YAML.load_file(log_file) : {}
  end

  def has_consented?
    return unless email
    log_data[cmail] && log_data[cmail]["consented_at"]
  end

  def consent_date
    return unless email
    log_data[cmail]["consented_at"]
  end

  def formatted_consent_date
    return unless email
    consent_date.to_time.strftime('%b-%d %H:%M') +
      BugmTime.now.strftime(' %Z')
  end

  def consented
    return unless email
    log_data[cmail] ||= {}
    log_data[cmail]["consented_at"] = Time.now
    save_log_data
  end

  def logged_in
    return unless email
    log_data[cmail] ||= {}
    log_data[cmail]["login_at"] = Time.now
    log_data[cmail]["num_logins"] = (log_data[cmail]["num_logins"] || 0) + 1
    save_log_data
  end

  private

  def save_log_data
    File.open(log_file, 'w') {|f| f.puts log_data.to_yaml}
  end

  def log_file
    @log_file ||= TS.trial_dir + "/.trial_data/AccessLog.yml"
  end
end
