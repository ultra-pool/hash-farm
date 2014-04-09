# -*- encoding : utf-8 -*-

require 'bitcoin'
require 'singleton'
require "protocol/stratum"
require "multicoin_pools/pool_picker"

require_relative './proxy_pool'
require_relative './worker_connection'

#
# The main pool recieve new connections,
# and allocate them to a pool.
class MainServer < Stratum::Server
  include Singleton
  include Loggable
  include Listenable

  attr_reader :pools, :current_pool

  def initialize
    @config = ProfitMining.config.main_server
    super( @config.host, @config.port )
    @handler = WorkerConnection
    @pools = []
    @balance = false
    @disconnected_workers = {}
    @min_pool_hashrate = ProfitMining.config.min_pool_hashrate
    @current_pool = nil

    init_event_machine
    init_pools
    init_listeners
  end

  def init_pools
    @pools = @config.proxy_pools.map { |name|
      begin
        pool = MulticoinPool[name].pool
        pool.on( 'error' ) do |error|
          log.error( "#{name} : #{error}" )
          emit( 'error', name, error )
        end
        pool.on( 'empty' ) do fill_holes end
        pool.on( 'low_hashrate' ) do fill_holes end
        pool
      rescue => err
        # TODO: ressayer plus tard ou sur le backup quand il y a un pb
        log.error "Fail to start ProxyPool #{name.inspect}. #{err}"
        nil
      end
    }.compact

    log.verbose "#{@pools.size} proxy_pools created."
  end

  def init_listeners
    on( 'connect' ) do |worker|
      worker.on( 'disconnect' ) do on_disconnect( worker ) end
      worker.mining.on('subscribe') do |req| on_subscribe( worker, req ) end
      worker.mining.on('authorize') do |req| on_authorize( worker, req ) end
    end
  end

  def start
    log.info "Starting CommandServer..."
    cs_conf = ProfitMining.config.command_server
    @command_server = EM.start_server( cs_conf.host, cs_conf.port, PM::CommandServer )
    log.info "CommandServer started on #{cs_conf.host}:#{cs_conf.port}"

    @pools.each(&:start)
    switch_to_next_pool
    super

    # @balance_timer = EM.add_periodic_timer( BALANCE_INTERVAL ) do
    #   balance_workers
    # end
    self
  end

  def stop
    super
    EM.stop_server @command_server
    @balance_timer.cancel if @balance_timer
    self
  end

  #############################################################################

  def on_subscribe worker, req
    sessionid = req.params[1]
    if sessionid.present? && @disconnected_workers[sessionid]
      log.info "#{worker.name} Restart session #{sessionid}"
      worker.reinit( @disconnected_workers.delete( sessionid )[1] )
    else
      log.info "#{worker.name} Choose best pool. sessionid : #{sessionid.present?}"
      choose_pool_for_new_worker.add_worker( worker )
    end
    worker.on_subscribe req
  end

  def on_authorize worker, req
    log.debug("authorizing #{req.params[0]}")
    username, _ = *req.params
    btc_address, worker_name = username.split('.')
    return req.respond( false ) if ! Bitcoin.valid_address?( btc_address )

    user = User.find_or_create_by!( btc_address: btc_address )
    worker.model = Worker.find_or_create_by!( user_id: user.id, name: worker_name )

    req.respond( true )
    log.verbose "[#{worker.name}] authorized => #{worker.name}."
  rescue => err
    log.error "MainServer.on_authorize #{worker.name} : #{err}\n" + err.backtrace[0..3].join("\n")
    req.respond( false )
    worker.close_connection
  end

  def on_disconnect worker
    old = Time.now.to_i - 60
    @disconnected_workers.delete_if { |sessionid, tab| tab.first < old }
    sessionid = worker.subscriptions["mining.notify"]
    @disconnected_workers[sessionid] = [Time.now.to_i, worker]
  end

  #############################################################################

  def workers
    @pools.map(&:workers).sum
  end

  def hashrate
    @pools.map(&:hashrate).sum
  end

  def rejected_hashrate
    @pools.map(&:rejected_hashrate).sum
  end

  # We received payout once a day, so real profitability is based on diff between 2 payouts.
  # We can estimated it based by calculating gains of each pool
  def profitability
    # based on 
    # @pools.map { |p|  }.sum
  end

  def choose_pool_for_new_worker
    return @current_pool if @current_pool.present?
    sorted_pools = @pools.sort_by { |p| p.profitability || 0.0 }.reverse
    sorted_pools.find { |p| p.workers.empty? } ||
    sorted_pools.find { |p| p.hashrate < @min_pool_hashrate } ||
    sorted_pools.first
  end

  def switch_to_next_pool
    if @current_pool.nil?
      next_pool_idx = 0
    else
      next_pool_idx = @pools.index( @current_pool ) + 1
      next_pool_idx %= @pools.size
    end
    log.info("Going to switch pool number #{next_pool_idx+1} on #{@pools.size}")

    self.current_pool = @pools[next_pool_idx]
    EM.add_timer( 4.days ) do
      switch_to_next_pool
    end
  rescue => err
    log.error err
  end

  def current_pool=( pool )
    log.info("Change current pool from #{@current_pool.name} to #{pool.name}") if @current_pool
    if @balance_timer
      @balance_timer.cancel
      @balance_timer = nil
    end
    @current_pool = pool
    move_all_workers
  end

  def move_all_workers( pool=@current_pool )
    log.info("Move all workers to #{pool.name}")
    workers.each do |w| w.pool = pool end
  end

  BALANCE_INTERVAL = 15.minutes

  def balance_workers
    return if self.workers.empty? || @pools.size <= 1
    fill_holes
    xtrm_balance
  rescue => err
    log.error "Error during workers balance : #{err}\n" + err.backtrace[0..5].join("\n")
  end

  # Try to have min_hashrate in each pools, or at least one worker.
  # Complete more profitable pools first.
  def fill_holes( pools=@pools, min_hashrate=@min_pool_hashrate )
    return if @current_pool.present?

    sorted_pools = pools.sort_by(&:profitability)

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

  XTRM_BALANCE_RATIO = 0.25 # %

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
    workers_taken = []
    hahrate_taken = 0

    for pool in sorted_pools
      log.verbose "for #{pool.name}, there are #{pool.workers.size} workers for %.2f Mhps" % (pool.hashrate.to_f / 10**6)
      pool_workers_taken, pool_hahrate_taken = get_workers_from( pool, hashrate_to_take - hahrate_taken,
        min_hashrate_to_leave, min_workers_to_leave )

      log.info "Retrieve %.2f Mh/s from #{pool.name}." % (pool_hahrate_taken * 10**-6) unless pool_workers_taken.empty?
      workers_taken += pool_workers_taken
      hahrate_taken += pool_hahrate_taken

      break if hashrate_to_take - hahrate_taken <= 10**6
    end

    [workers_taken, hahrate_taken]
  end

  # => ary of Worker
  def get_workers_from( pool, hashrate_to_take, min_hashrate_to_leave=@min_pool_hashrate, min_workers_to_leave=1 )
    return [ [], 0.0 ] if pool.workers.size <= min_workers_to_leave
    return [pool.workers, pool.hashrate] if pool.workers.size == 1 && min_workers_to_leave == 0 && min_hashrate_to_leave == 0

    sorted_workers = pool.workers.sort_by(&:hashrate)
    pool_workers_taken = []

    can_take_hashrate = pool.hashrate - min_hashrate_to_leave
    can_take_worker = sorted_workers.size - min_workers_to_leave
    hashrate_taken = 0

    # Try all 1 or 2 combinaison of worker and take the closest of hashrate_to_take
    for i in 1..[can_take_worker, 2].min
      # TODO: improve this function, can be much smarter
      sorted_workers.combination(i) do |t|
        hashrate = t.map(&:hashrate).sum
        leave_hashrate = pool.hashrate - hashrate
        next if leave_hashrate < min_hashrate_to_leave
        # A partir de là, la combinaison satisfait min_hashrate_to_leave et min_workers_to_leave
        current_diff = (hashrate_to_take - hashrate_taken).abs
        diff = (hashrate_to_take - hashrate).abs
        next if current_diff < diff
        pool_workers_taken = t
        hashrate_taken += hashrate
      end
    end

    [pool_workers_taken, hashrate_taken]
  end

  def inspect
    "#MainPool@%s:%s{workers: %d, proxys: %d}" % [host, port, 0, @pools.size]
  end

  def to_s
    s = "MainPool@%s:%s : %d workers, %d pools" % [host, port, 0, @pools.size]
    s += "\n" + @pools.map(&:to_s).join("\n") # Tant qu'on est en test et qu'il y a peu de mineurs.
    # s += "\n" + @pools.map(&:inspect)
    s
  end

end
