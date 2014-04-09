# -*- encoding : utf-8 -*-

require 'nokogiri'
require 'mechanize'
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
    @timer_delay = 10.minute

    super
  end

  # Because we do not have the paid field, we must handle cashout breaks.
  def gains( since=3.hour.ago, untl=Time.now )
    idx_untl = stats.size-1
    idx_untl -= 1 while idx_untl > 0 && stats[idx_untl][:timestamp] > untl
    idx_since = idx_untl
    idx_since -= 1 while idx_since > 0 && stats[idx_since][:timestamp] > since

    return 0.0 if idx_since == idx_untl

    gain1 = stats[idx_since].values_at( :immature, :unexchanged ).sum
    gain1 += stats[idx_since][:balance] unless stats[idx_untl][:balance] < stats[idx_since][:balance] # Cashout
    gain2 = stats[idx_untl].values_at( :immature, :unexchanged, :balance ).sum

    gain2 - gain1
  end

  def load_page
    # url = "https://www.wemineall.com/api?api_key=9952126c07691f80b5864c766eb47f3e9f6f44c00c8801a65c6ed1024b403f62"
    # s = open( url ).read
    # raise s if s =~ /^API Throttle/
    # h = JSON.parse( s )
    # puts "--> Il y a du NOUVEAU chez WeMineALL-API !!" if h.keys != ["username", "confirmed_rewards", "round_estimate", "total_hashrate", "round_shares", "workers"]
    # puts "--> Il y a du NOUVEAU chez WeMineALL-API !!" if h["confirmed_rewards"].present?
    # h = h["workers"]["ProfitMining.proxy"]
    # p h

    agent = Mechanize.new
    agent.post("https://www.wemineall.com/login", {username: 'ProfitMining', password: 'profit69'})
    page = agent.get("https://www.wemineall.com/accountWallets")
    balance = page.search(".block_content tbody").first.search("tr:first td:nth(2)").first.text.to_f
    beeing_exchanged = page.search(".block_content tbody").first.search("tr").last.search("td").last.text.to_f
    hashrate_mh = page.search("#leftsidebarinner > .block_content > p > i:first").first.text.to_f / 1000.0

    super( hashrate_mh, 0, 0, beeing_exchanged, balance, 0 )
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
