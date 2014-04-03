# -*- encoding : utf-8 -*-

require 'nokogiri'
require 'open-uri'
require 'singleton'

require 'multicoin_pool'

class CleverMining < MulticoinPool
  include Singleton

  def initialize
    @url = "stratum+tcp://eu.clevermining.com:3333"
    @url_back = "stratum+tcp://ny.clevermining.com:3333"
    @account = '186e2PUgDoEZ14t25wYN8x1Ry5gtV3Qvj1'
    @stats_file = "db/stats/clever_mining.yaml"
    # Disable stats fetching due to CloudFire anti-DDos system blocking us.
    # @timer_delay = 45.second

    super
  end

  # HEADERS = {
  #   "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/32.0.1700.102 Chrome/32.0.1700.102 Safari/537.36",
  #   "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
  #   "Accept charset" => "",
  #   "Accept encoding" => "gzip,deflate,sdch",
  #   "Accept language" => "fr-FR,fr;q=0.8,en-US;q=0.6,en;q=0.4",
  #   "Referer" => "",
  #   "Connection" => "keep-alive",
  #   proxy: "http://176.31.241.53:3128/"
  # }
  # def load_page
  #   page = Nokogiri::HTML( open( "http://www.clevermining.com/users/#{@account}", HEADERS ) )
  #   table1 = page.search(".balances").first
  #   balances = table1.search("td").map(&:text).map(&:to_f)
  #   balances << page.search(".table:contains(Total Profits) tr:first td").first.text.to_f
  #   mhs = page.search(".easy-pie-chart span, .easy-pie-chart + p.text-muted").map(&:text).map(&:to_f)
  #   super( *(mhs + balances) )
  # rescue => err
  #   MulticoinPool.log.error "in #{name}.load_page : #{err}\n" + err.backtrace[0...2].join("\n")
  # end
end
