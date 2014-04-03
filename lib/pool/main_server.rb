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

  attr_reader :pools

  def initialize
    @config = ProfitMining.config.main_server
    super( @config.host, @config.port )
    @handler = WorkerConnection
    @pools = []
    @balance = false
    @disconnected_workers = {}

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
    super
    @balance_timer = EM.add_periodic_timer( BALANCE_INTERVAL ) do
      balance_workers
    end
    self
  end

  def stop
    super
    EM.stop_server @command_server
    @balance_timer.cancel
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
    sorted_pools = @pools.sort_by { |p| p.profitability || 0.0 }.reverse
    sorted_pools.find { |p| p.workers.empty? } ||
    sorted_pools.find { |p| p.hashrate < MIN_POOL_HASHRATE } ||
    sorted_pools.first
  end

  BALANCE_INTERVAL = 5 * 60 # second

  def balance_workers
    xtrm_balance
  rescue => err
    log.error "Error during workers balance : #{err}\n" + err.backtrace[0..5].join("\n")
  end

  XTRM_BALANCE_RATIO = 0.25 # %
  MIN_POOL_HASHRATE = 2.0 * 10**6 # Minimun Mhs per pool

  def xtrm_balance
    sorted_pools = @pools.sort_by { |p| p.profitability || 0.0 }
    best_index = -1
    # best_index = sorted_pools.find_index { |p| p.workers.empty? }
    best_pool = sorted_pools.delete_at(best_index)
    return if sorted_pools.empty?
    
    to_take = self.hashrate * XTRM_BALANCE_RATIO
    workers_taken = []
    workers_taken_hahrate = 0.0

    log.info "xtrm_balance : best pool is #{best_pool.name}, we want to take %.2f Mhps" % (to_take / 10**6)

    workers_taken, workers_taken_hahrate = *get_workers( sorted_pools, to_take )
    
    # Si best_pool.hashrate < à MIN_POOL_HASHRATE, on force.
    if workers_taken_hahrate + best_pool.hashrate < MIN_POOL_HASHRATE
      res = get_workers( sorted_pools, to_take - workers_taken_hahrate, 0 )
      workers_taken += res.first
      workers_taken_hahrate += res.last

      if workers_taken.size + best_pool.workers.size < 1
        workers_taken = sorted_pools.first.workers.first
        workers_taken_hahrate = workers_taken.first.hashrate
      end
    end

    workers_taken.each { |w| w.pool = best_pool }
    log.info "%.2f Mh/s added to #{best_pool.name}." % (workers_taken_hahrate / 10**6)
  rescue => err
    log.error "Error during xtrm_balance : #{err}\n" + err.backtrace[0..5].join("\n")
  end

  def get_workers( sorted_pools, hashrate_to_take, min_hashrate_to_leave=MIN_POOL_HASHRATE, min_workers_to_leave=1 )
    workers_taken = []
    hahrate_taken = 0

    for pool in sorted_pools
      log.info "for #{pool.name}, there are #{pool.workers.size} workers for %.2f Mhps" % (pool.hashrate.to_f / 10**6)
      pool_workers_taken, pool_hahrate_taken = get_workers_from( pool, hashrate_to_take - hahrate_taken,
        min_hashrate_to_leave, min_workers_to_leave )

      log.info "Retrieve %.2f Mh/s from #{pool.name}." % (pool_hahrate_taken * 10**-6)
      workers_taken += pool_workers_taken
      hahrate_taken += pool_hahrate_taken

      break if hashrate_to_take - hahrate_taken <= 10**6
    end

    [workers_taken, hahrate_taken]
  end

  # => ary of Worker
  def get_workers_from( pool, hashrate_to_take, min_hashrate_to_leave=MIN_POOL_HASHRATE, min_workers_to_leave=1 )
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
