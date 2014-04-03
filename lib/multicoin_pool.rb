# -*- encoding : utf-8 -*-

require 'open-uri'

require 'pool/proxy_pool'
require 'multicoin_pools/pool_picker' 
class MulticoinPool
  include Loggable

  def self.[]( pool_name )
    require "multicoin_pools/#{pool_name}"
    pool_name.camelize.constantize.instance
  rescue
    nil
  end

  attr_reader :name
  attr_reader :url, :url_back
  attr_reader :uri, :uri_back
  attr_reader :account, :password
  attr_reader :pool
  # An Array of Hash{:accepted_mh, :rejected_mh, :immature, :unexchanged, :balance, :paid, :timestamp}
  attr_reader :stats
  attr_reader :stats_file
  attr_accessor :timer_delay

  def initialize
    @name = self.class.name

    @uri = URI(@url)
    @uri.user = @account
    @uri.password = @password

    if @url_back
      @uri_back = URI(@url_back)
      @uri_back.user = @account
      @uri_back.password = @password
    end

    @pool = ProxyPool.new(@uri, name: @name, back: @uri_back, profitability: -> { self.profitability } )

    `touch #{@stats_file}`
    @stats = load_stats

    Thread.new do EM.run end if ! EM.reactor_running?
    EM.add_timer( 5 ) do start_load_page_timer end if @timer_delay
  end

  def start_load_page_timer
    if @stats[-1].nil? || Time.now - @stats[-1][:timestamp] > 1.hour
      t = 0.0
    else
      t = 1.hour - (Time.now - @stats[-1][:timestamp])
    end
    MulticoinPool.log.info "[#{name}] start timer in #{t}"
    EM.add_timer( t ) do
      MulticoinPool.log.info "[#{name}] Going to load page (one-shot timer)"
      Thread.new { load_page
        MulticoinPool.log.info "[#{name}] page loaded" }
      EM.cancel_timer( @timer ) if @timer
      @timer = EM.add_periodic_timer( @timer_delay ) do
        MulticoinPool.log.info "[#{name}] Going to load page (periodic timer)"
        Thread.new { load_page
          MulticoinPool.log.info "[#{name}] page loaded" }
      end
    end
  end

  # BTC / MH/s / day
  def profitability
    return PoolPicker.profitability_of( @name.camelize ) if stats[-2].nil?

    _2hour_idx = stats.size - 2
    _2hour_idx -= 1 while _2hour_idx > 0 && stats[-1][:timestamp] - stats[_2hour_idx][:timestamp] < 2.hour
    
    gain1 = stats[-1].values_at( :immature, :unexchanged, :balance, :paid ).sum
    gain2 = stats[_2hour_idx].values_at( :immature, :unexchanged, :balance, :paid ).sum
    gain = gain1 - gain2
    hashrate = stats.last[:accepted_mh]
    delay = stats[-1][:timestamp] - stats[_2hour_idx][:timestamp]

    raise "No worker is mining on #{@name} with account #{@account}" if hashrate == 0.0
    gain / hashrate / delay * 1.day
  rescue => err
    MulticoinPool.log.warn err.message
    PoolPicker.profitability_of( @name )
  end

  def load_page( accepted_mh, rejected_mh, immature, unexchanged, balance, paid )
    # If values haven't changed.
    return if @stats[-1].present? && [immature, unexchanged, balance, paid] == @stats[-1].values_at(:immature,:unexchanged,:balance,:paid)
    hash = {
      accepted_mh: accepted_mh,
      rejected_mh: rejected_mh,
      immature: immature,
      unexchanged: unexchanged,
      balance: balance,
      paid: paid,
      timestamp: Time.now
    }
    @stats << hash
    save_stats( hash )
    hash
  rescue => err
    MulticoinPool.log.error "in #{name}.load_page : #{err}\n" + err.backtrace[0...2].join("\n")
    hash
  end

  def save_stats( line=nil )
    if line
      File.open( @stats_file, 'a' ) do |f| f.puts [line].to_yaml.sub( /^---\n/, '' ) end
    else
      File.open( @stats_file, 'w' ) do |f| f.puts stats.to_yaml end
    end
  rescue => err
    MulticoinPool.log.error "in #{@name}.save_stats : #{err}\n" + err.backtrace[0...2].join("\n")
  end

  def load_stats
    t = YAML.load( open( @stats_file ) ) || []
    stats = t[(t.size > 50 ? -50 : 0)..-1]
  rescue => err
    MulticoinPool.log.error "in #{@name}.load_stats : #{err}\n" + err.backtrace[0...2].join("\n")
  end
end
