# -*- encoding : utf-8 -*-

require 'nokogiri'
require 'open-uri'
require 'singleton'

require 'multicoin_pool'

class Middlecoin < MulticoinPool
  include Singleton

  def initialize
    @url = "stratum+tcp://amsterdam.middlecoin.com:3333"
    @url_back = "stratum+tcp://@eu.middlecoin.com:3333"
    @account = '186e2PUgDoEZ14t25wYN8x1Ry5gtV3Qvj1'
    @stats_file = "db/stats/middlecoin.yaml"
    @timer_delay = 10.minute

    super
  end

  def load_page
    # TODO: passer en json
    page = Nokogiri::HTML( open( "http://www.middlecoin.com/allusers.html" ) )
    tr = page.search("tr").find { |tr| tr.children.first.text == @account } 
    tds = tr.children.select { |e| e.name == 'td' }
    values = tds[1..-1].map(&:text).map(&:to_f)
    super( *values )
  rescue => err
    MulticoinPool.log.error "in #{name}.load_page : #{err}\n" + err.backtrace[0...2].join("\n")
  end
end
