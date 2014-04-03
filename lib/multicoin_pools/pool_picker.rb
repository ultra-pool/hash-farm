# -*- encoding : utf-8 -*-

require 'nokogiri'
require 'open-uri'

module PoolPicker
  VALIDITY = 1.day

  @@validity = Time.now
  @@data = {}

  def self.supported_pools
    get_data.keys
  end

  def self.profitability_of pool_name
    n = 3 # Mean on n last stat, due to good and bad days
    get_data[pool_name.downcase][0...n].sum / n
  rescue => err
    puts "in PoolPicker.profitability_of #{pool_name} : #{err}\n" + err.backtrace[0...2].join("\n")
    nil
  end

  def self.get_data
    return @@data if @@validity > Time.now
    @@validity = Time.now + VALIDITY

    page = Nokogiri::HTML( open( "http://poolpicker.eu/text.php" ) )
    pools_name = page.search(".btcmhs th")[1..-1].map(&:text).map(&:downcase)
    @@data = pools_name.size.times.map { |idx|
      idx += 2
      profs = page.search(".btcmhs tr td:nth-of-type(#{idx})").map(&:text).map(&:to_f)
      profs
    }
    @@data = pools_name.zip( @@data ).to_h
    @@data
  end
end
