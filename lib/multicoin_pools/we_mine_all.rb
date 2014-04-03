# -*- encoding : utf-8 -*-

require 'nokogiri'
require 'open-uri'
require 'singleton'

require 'multicoin_pool'

class WeMineAll < MulticoinPool
  include Singleton

  def initialize
    @url = "stratum+tcp://multi1.wemineall.com:5555"
    @url_back = "stratum+tcp://multi2.wemineall.com:5555"
    @account = 'ProfitMining.proxy'
    @password = 'toto'
    @stats_file = "db/stats/we_mine_all.yaml"
    @timer_delay = 15.minute

    super
  end

  def load_page
    url = "https://www.wemineall.com/api?api_key=9952126c07691f80b5864c766eb47f3e9f6f44c00c8801a65c6ed1024b403f62"
    s = open( url ).read
    raise s if s =~ /^API Throttle/
    h = JSON.parse( s )
    raise "--> Il y a du NOUVEAU chez WeMineALL-API !!" if h.keys != ["username", "confirmed_rewards", "round_estimate", "total_hashrate", "round_shares", "workers"]
    raise "--> Il y a du NOUVEAU chez WeMineALL-API !!" if h["confirmed_rewards"].present?
    h = h["workers"]["ProfitMining.proxy"]
    p h
    super( h["hashrate"].to_i * 10**-6, 0, 0, 0, 0, 0 )
  rescue => err
    if err.message =~ /^API Throttle/
      sleep( 60 )
      retry
    else
      MulticoinPool.log.error "in #{name}.load_page : #{err}\n" + err.backtrace[0...2].join("\n")
      nil
    end
  end
end
