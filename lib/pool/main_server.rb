# -*- encoding : utf-8 -*-

require 'bitcoin'
require 'singleton'
require "protocol/stratum"
require "command_server"
require "multicoin_pools/pool_picker"

require_relative './proxy_pool'
require_relative './rent_pool'
require_relative './worker_connection'
autoload( :RentServer, 'pool/rent_server' )

# MainServer is a very basic worker balancer over pools,
# it just took the better.
#
# The main pool receive new connections,
# and allocate them to a pool. 
class MainServer < Stratum::Server
  include Singleton
  include Loggable
  include Listenable


  # Define here the main server to use.
  def MainServer.instance
    # MainServer.instance
    RentServer.instance
  end

  attr_reader :pools, :current_pool

  def initialize
    @config = ProfitMining.config.main_server
    super( @config.host, @config.port )
    @handler = WorkerConnection
    @pools = []
    @disconnected_workers = {}
    @current_pool = nil

    init_event_machine
    init_pools
    init_listeners
  end

  def init_pools
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
  end

  # => self
  def stop
    EM.stop_server @command_server
    super
  end

  # => pool
  def add_pool( pool )
    pool.on( 'error' ) do |error|
      log.error( "#{pool.name} : #{error}" )
      emit( 'error', pool.name, error )
    end

    @pools << pool
    if self.started?
      pool.start
      pool.on('started') do balance_workers end
    end
    pool
  end
  
  def delete_rent_pool( pool )
    @pools.delete( pool )
    pool.on('empty') do pool.stop end
    pool.workers.each do |w| w.pool = choose_pool_for_new_worker end
  end


  #############################################################################

  def on_subscribe worker, req
    sessionid = req.params[1]
    if sessionid.present? && @disconnected_workers[sessionid]
      log.info "#{worker.name} Restart session #{sessionid}"
      worker.reinit( @disconnected_workers.delete( sessionid )[1] )
    else
      log.info "#{worker.name} Start new session."
      choose_pool_for_new_worker.add_worker( worker )
    end
    worker.on_subscribe req
  end

  def on_authorize worker, req
    log.debug("authorizing #{req.params[0]}")
    username, _ = *req.params
    payout_address, worker_name = username.split('.')
    return req.respond( false ) if ! Bitcoin.valid_address?( payout_address )

    user = User.find_or_create_by!( payout_address: payout_address )
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
    log.info "#{worker.name} Disconnected."
  end


  #############################################################################

  # Virtual
  def choose_pool_for_new_worker
    @current_pool || @pools.max
  end

  # Virtual
  def balance_workers
    return if self.workers.empty? || @pools.size <= 1
    move_all_workers( choose_pool_for_new_worker )
  rescue => err
    log.error "Error during workers balance : #{err}\n" + err.backtrace[0..5].join("\n")
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

  def switch_to_next_pool
    if @current_pool.nil?
      next_pool_idx = 0
    else
      next_pool_idx = @pools.index( @current_pool ) + 1
      next_pool_idx %= @pools.size
    end
    log.info("Going to switch to pool n°#{next_pool_idx+1}/#{@pools.size}")

    self.current_pool = @pools[next_pool_idx]
    # EM.add_timer( 4.days ) do switch_to_next_pool end
    self.current_pool
  rescue => err
    log.error err
  end

  # => pool
  def current_pool=( pool )
    return pool if @current_pool == pool
    if @current_pool && pool
      log.info "Change current pool from #{@current_pool.name} to #{pool.name}"
    elsif @current_pool
      log.info "Change current pool from #{@current_pool.name} to nil" 
    elsif pool
      log.info("Change current pool to #{pool.name}")
    end

    @current_pool = pool
    if pool
      move_all_workers
    else
      balance_workers
    end
  end

  def move_all_workers( pool=@current_pool )
    raise "pool must be a Pool, not a #{pool.class}" if ! pool.kind_of?( Pool )
    log.info("Move all workers to #{pool.name}")
    workers.each do |w| w.pool = pool end
  end

  def get_workers( sorted_pools, hashrate_to_take, min_hashrate_to_leave=0, min_workers_to_leave=0 )
    workers_taken = []
    hahrate_taken = 0

    for pool in sorted_pools
      log.info "for #{pool.name}, there are #{pool.workers.size} workers for %.2f Mhps" % (pool.hashrate.to_f / 10**6)
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
  def get_workers_from( pool, hashrate_to_take, min_hashrate_to_leave=0, min_workers_to_leave=0 )
    return [ [], 0.0 ] if pool.workers.size <= min_workers_to_leave
    return [pool.workers, pool.hashrate] if pool.workers.size == 1 && min_workers_to_leave == 0 && min_hashrate_to_leave == 0

    sorted_workers = pool.workers.sort_by(&:hashrate)
    pool_workers_taken = []

    can_take_hashrate = pool.hashrate - min_hashrate_to_leave
    can_take_worker = sorted_workers.size - min_workers_to_leave
    hashrate_taken = 0

    # Try all 1 or 2 combinaison of worker and take the closest of hashrate_to_take
    # for i in 1..[can_take_worker, 2].min
    #   # TODO: improve this function. Can be much smarter.
    #   sorted_workers.combination(i) do |t|
    #     hashrate = t.map(&:hashrate).sum
    #     leave_hashrate = pool.hashrate - hashrate
    #     next if leave_hashrate < min_hashrate_to_leave
    #     # A partir de là, la combinaison satisfait min_hashrate_to_leave et min_workers_to_leave
    #     current_diff = (hashrate_to_take - hashrate_taken).abs
    #     diff = (hashrate_to_take - hashrate).abs
    #     next if current_diff < diff
    #     pool_workers_taken = t
    #     hashrate_taken += hashrate
    #   end
    # end

    while hashrate_taken < hashrate_to_take && pool.hashrate - hashrate_taken > min_hashrate_to_leave && pool.workers.size - pool_workers_taken.size > min_workers_to_leave
      w = sorted_workers.shift
      pool_workers_taken << w
      hashrate_taken += w.hashrate
    end

    [pool_workers_taken, hashrate_taken]
  end

  def inspect
    "#MainPool@%s:%s{workers: %d, pools: %d}" % [host, port, 0, @pools.size]
  end

  def to_s
    s = "MainPool@%s:%s : %d workers, %d pools" % [host, port, 0, @pools.size]
    s += "\n" + @pools.map(&:to_s).join("\n") # Tant qu'on est en test et qu'il y a peu de mineurs.
    # s += "\n" + @pools.map(&:inspect).join("\n")
    s
  end
end
