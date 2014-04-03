# -*- encoding : utf-8 -*-
require 'open-uri'
require 'net/http'
require 'json'

require_relative "../chart"

# Get some general informations about crypto currencies
# like current block reward and average profit
# on http://www.coinwarz.com/
class CoinWarz < Chart
  # en seconde
  REFRESH_RATE = 3600
  API_KEY = "04a07938106844b6a692b3d77937c701"

  @@data = nil
  @@data_date = nil

  # Hash of String => Hash
  def self.data
    self.loadFromFile if @@data.nil?
    self.loadFromWebsite if @@data.nil? || ( @@data_date + REFRESH_RATE < Time.now )
    @@data || {}
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
    return data[currency]["Difficulty"].to_f
  end

  # => Float
  def self.get_reward currency
    return data[currency]["BlockReward"].to_f
  end

  # => Float
  def self.get_block_delay currency
    data[currency]["BlockTimeInSeconds"].to_f
  end

  # => Integer
  def self.get_block_count currency
    data[currency]["BlockCount"].to_f
  end

  private

    def self.loadFromFile
      str = File.open("./coin_warz.json", "r") do |file|
        file.read
      end
      hash = JSON.parse str
      @@data_date = Time.parse hash["Timestamp"]

      @@data = {}
      for o in hash["Data"]
        next if o["Algorithm"] != 'Scrypt'
        @@data[ o["CoinTag"] ] = o
      end
      @@data
    rescue
      nil
    end

    def self.loadFromWebsite
      raise "loadFromWebsite #{@@data.nil?} #{@@data_date + REFRESH_RATE} #{Time.now}" unless @@data.nil? || ( @@data_date + REFRESH_RATE < Time.now )
      res = Net::HTTP.get_response(URI("http://www.coinwarz.com/v1/api/profitability/?apikey=#{API_KEY}&algo=scrypt"))
      raise "HTTPError code #{res.code} : " if res.code.to_i != 200
      hash = JSON.parse res.body
      raise "Waited a Hash, got a #{hash.class}" if ! hash.kind_of?( Hash )
      raise hash["Message"] if ! hash["Success"]

      @@data_date = hash["Timestamp"] = Time.now
      self.save hash
      @@data = {}
      for o in hash["Data"]
        @@data[ o["CoinTag"] ] = o
      end
      @@data
    rescue => err
      puts "Warning: error retrieving CoinWarz data : #{err}"
      nil
    end

    def self.save hash
      File.open("./coin_warz.json", "w") do |file|
        file.puts hash.to_json
      end
      nil
    end
end
