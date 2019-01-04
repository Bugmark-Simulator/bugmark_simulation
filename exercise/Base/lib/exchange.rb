# SPDX-License-Identifier: MPL-2.0
class Exchange
  class << self
    def src_dir
      src  = File.expand_path("~/src")
      src1 = src + "/exchange"
      src2 = src + "/bugmark/exchange"
      return src1 if File.exist?(src1)
      return src2 if File.exist?(src2)
      raise "Exchange directory not found"
    end

    def load_rails
      orig = $VERBOSE
      $VERBOSE = nil
      require src_dir + "/config/environment"
      $VERBOSE = orig
    end
  end
end
