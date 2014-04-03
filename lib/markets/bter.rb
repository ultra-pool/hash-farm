# -*- encoding : utf-8 -*-

require 'open-uri'
require 'openssl'
require 'net/http'
require 'json'

require_relative '../market'

# Doc : http://bter.com/api
class Bter < Market

  # en seconde
  REFRESH_RATE = 60

  # => Array of String
  def self.supported_currencies
    pairs.flatten.uniq
  end

  # => Boolean
  def self.support?(from, to)
    pairs.include?([from, to]) || pairs.include?([to, from])
  end

  # => Float
  def self.last_trade from, to
    market = tickers["#{from}_#{to}".downcase]
    return market["last"].to_f if market.kind_of?(Hash)
    market = tickers["#{to}_#{from}".downcase]
    return 0.0 if market.nil?
    1.0 / market["last"].to_f
  end

  def self.pairs
    get("http://bter.com/api/1/pairs", 60*60).map { |pair| pair.upcase.split("_") }
  end

  def self.tickers
    get("http://bter.com/api/1/tickers", 60*5)
  end

  def self.depth from, to
    get("http://bter.com/api/1/depth/#{from}_#{to}")
  end

  private
    def self.get url, refresh_rate=REFRESH_RATE
      hash = Market.get(url, refresh_rate)
      puts "Warning: \"result\" is false retrieving #{url.inspect}" if hash.kind_of?(Hash) && hash["result"] && hash["result"] != "true"
      hash
    end

end
