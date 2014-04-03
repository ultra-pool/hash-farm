# -*- encoding : utf-8 -*-
require 'open-uri'
require 'net/http'
require 'json'

require_relative "../chart"

# Get some general informations about crypto currencies
# like current block reward and average profit
# on http://www.coinchoose.com/
class CoinChoose < Chart
  # en seconde
  REFRESH_RATE = 60

  @@data = nil
  @@data_date = nil

  # Raw data
  # Hash of String => Hash
  def self.data
    self.update if @@data.nil? || @@data_date + REFRESH_RATE < Time.now
    @@data
  end

  # => Array of String
  def self.supported_currencies
    data.keys
  end

  # => Boolean
  def self.support? currency
    !! data[currency]
  end

  # => Float
  def self.get_difficulty currency
    return data[currency]["difficulty"].to_f
  end

  # => Float
  def self.get_avg_profit currency
    return data[currency]["avgProfit"].to_f
  end

  # => Float
  def self.get_reward currency
    return data[currency]["reward"].to_f
  end

  # => Float
  def self.get_block_delay currency
    return data[currency]["minBlockTime"].to_f * 60
  end

  private

    # Return on successful update, false otherwise
    def self.update
      res = Net::HTTP.get_response(URI("http://www.coinchoose.com/api.php?base=BTC"))
      return false if res.code.to_i != 200
      ary = JSON.parse res.body
      return false if ! ary.kind_of?( Array )
      hash = {}
      for o in ary
        hash[ o["symbol"] ] = o
        hash[ "DOGE" ] = o if o["symbol"] == "DOG"
      end
      @@data_date = Time.now
      @@data = hash
      true
    rescue => err
      puts err
      false
    end
end
