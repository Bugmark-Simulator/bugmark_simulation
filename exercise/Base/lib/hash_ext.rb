require 'openssl'

class Hash
  def multi_merge(*subhash)
    subhash.reduce(self) do |acc, hsh|
      acc.merge(hsh)
    end
  end
end