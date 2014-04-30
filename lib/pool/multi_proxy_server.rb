# -*- encoding : utf-8 -*-

require_relative './main_server'

# The MultiProxyServer create ProxyPools,
# and try to leave a minimum hashrate in each pool to compute real-time profitability.
# It balance every BALANCE_INTERVAL some workers (XTRM_BALANCE_RATIO) from worst pool to best pool.
class MultiProxyServer < MainServer
  include Loggable

  BALANCE_INTERVAL = 15.minutes
  XTRM_BALANCE_RATIO = 0.25 # %

  def initialize(*)
    super
    @min_pool_hashrate = @config.min_pool_hashrate
    @balance = false    
  end

  def init_pools
    @config.proxy_pools.map { |name|
      pool = add_proxy_pool( name )
    }
    log.verbose "#{@pools.size} proxy_pools created."
  end

  def start
    super
    @balance_timer = EM.add_periodic_timer( BALANCE_INTERVAL ) do
      balance_workers
    end
    self
  end

  def stop
    EM.cancel_timer( @balance_timer )
    super
  end

  # => proxyPool
  def add_proxy_pool( name )
    pool = MulticoinPool[name].pool
    pool.on( 'empty' ) do fill_holes end
    pool.on( 'low_hashrate' ) do fill_holes end
    add_pool( pool )
  rescue => err
    log.error "#{err}\n" + err.backtrace[0...5].join("\n")
    nil
  end


  #############################################################################

  def choose_pool_for_new_worker
    sorted_pools = @pools.sort_by { |p| p.profitability || 0.0 }.reverse
    sorted_pools.find { |p| p.workers.empty? } ||
    sorted_pools.find { |p| p.hashrate < @min_pool_hashrate } ||
    sorted_pools.first
  end

  def balance_workers
    return if self.workers.empty? || @pools.size <= 1
    fill_holes
    xtrm_balance
  rescue => err
    log.error "Error during workers balance : #{err}\n" + err.backtrace[0..5].join("\n")
  end


  #############################################################################

  # Try to have min_hashrate in each pools, or at least one worker.
  # Complete more profitable pools first.
  def fill_holes( pools=@pools, min_hashrate=@min_pool_hashrate )
    return if @current_pool.present?

    sorted_pools = pool.sort_by(&:profitability)

    # Balance each pool to have min_hashrate or at least 1 worker
    sorted_pools.each_with_index do |pool, i|
      begin
        next unless pool.workers.empty? || pool.hashrate < min_hashrate
        log.verbose "fill_holes : #{pool.name} has %.1f MH/s and %d workers. We want to take %.1f Mhps" % [pool.hashrate * 10**-6, pool.workers.size, min_hashrate / 10**6]
        res = get_workers( sorted_pools[0..i], min_hashrate - pool.hashrate )
        res.first.each do |w| w.pool = pool end

        next unless pool.workers.empty? || pool.hashrate < min_hashrate
        log.verbose "fill_holes : #{pool.name} has %.1f MH/s and %d workers. We want to take %.1f Mhps" % [pool.hashrate * 10**-6, pool.workers.size, min_hashrate / 10**6] unless res.first.empty?
        res = get_workers( sorted_pools[i+1..-1], min_hashrate - pool.hashrate )
        res.first.each do |w| w.pool = pool end

        next unless pool.workers.empty? || pool.hashrate < min_hashrate
        log.verbose "fill_holes : #{pool.name} has %.1f MH/s and %d workers. We want to take %.1f Mhps" % [pool.hashrate * 10**-6, pool.workers.size, min_hashrate / 10**6] unless res.first.empty?
        res = get_workers( sorted_pools[0...i], min_hashrate - pool.hashrate, 0 ) # leave one worker
        res.first.each do |w| w.pool = pool end

        next unless pool.workers.empty?
        log.verbose "fill_holes : #{pool.name} has %.1f MH/s and %d workers. We want to take 1 worker" % [pool.hashrate * 10**-6, pool.workers.size] unless res.first.empty?
        res = get_workers( sorted_pools[i+1..-1], min_hashrate - pool.hashrate, 0 )
        res.first.first.pool = pool if res.first.size > 0

        next unless pool.workers.empty?
        log.verbose "fill_holes : #{pool.name} has %.1f MH/s and %d workers. We want to take 1 worker" % [pool.hashrate * 10**-6, pool.workers.size] unless res.first.empty?
        res = get_workers( sorted_pools[0...i], min_hashrate - pool.hashrate, 0, 0 )
        res.first.first.pool = pool if res.first.size > 0

      rescue => err
        log.error "Error during xtrm_balance : #{err}\n" + err.backtrace[0..5].join("\n")
      ensure
        log.info "fill_holes : #{pool.name} has now %.1f MH/s and %d workers." % [pool.hashrate * 10**-6, pool.workers.size]
      end
    end

    self
  end

  def xtrm_balance
    sorted_pools = @pools.sort_by(&:profitability)

    best_pool = sorted_pools[-1]
    to_take = self.hashrate * XTRM_BALANCE_RATIO
    log.info "xtrm_balance : best pool is #{best_pool.name}, we want to take %.2f Mhps" % (to_take / 10**6)
    res = get_workers( sorted_pools[0...-1], to_take )
    res.first.each do |w| w.pool = best_pool end

    log.info "%.2f Mh/s added to #{best_pool.name}." % (res.last / 10**6)
    res
  rescue => err
    log.error "Error during xtrm_balance : #{err}\n" + err.backtrace[0..5].join("\n")
  end

  def get_workers( sorted_pools, hashrate_to_take, min_hashrate_to_leave=@min_pool_hashrate, min_workers_to_leave=1 )
    super
  end

  # => ary of Worker
  def get_workers_from( pool, hashrate_to_take, min_hashrate_to_leave=@min_pool_hashrate, min_workers_to_leave=1 )
    super
  end
end