# -*- encoding : utf-8 -*-

require 'nokogiri'
require 'open-uri'
require 'singleton'

require 'multicoin_pool'

class Coinshift < MulticoinPool
  include Singleton

  def initialize
    @url = "stratum+tcp://mine.coinshift.com:3333"
    @url_back = "stratum+tcp://backup.coinshift.com:3333"
    @account = '186e2PUgDoEZ14t25wYN8x1Ry5gtV3Qvj1'
    @stats_file = "db/stats/coinshift.yaml"
    @timer_delay = 15.minute

    super
  end

  def load_page
    page = Nokogiri::HTML( open( "http://coinshift.com/account/#{@account}" ) )
    h3s = page.search(".col-md-4 h3").map(&:text).map(&:to_f)
    mhs = h3s.shift(2).map { |kh| kh / 1000 }
    balances = [0.0] + h3s.reverse
    balances << page.search(".col-md-12 strong").first.text.to_f
    balances
    super( *(mhs + balances) )
  rescue => err
    MulticoinPool.log.error "in #{name}.load_page : #{err}\n" + err.backtrace[0...2].join("\n")
    nil
  end
end
