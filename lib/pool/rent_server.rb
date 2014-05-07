# -*- encoding : utf-8 -*-

require_relative './main_server'

#
class RentServer < MainServer
  include Loggable

  CHECK_ORDERS_POOL_EVERY = 1.minute

  def init_pools
    log.verbose "#{@pools.size} rent_pools created."
  end

  def start
    @check_orders_timer = EM.add_periodic_timer( CHECK_ORDERS_POOL_EVERY ) { check_orders }
    on( 'started' ) { check_orders }
    super
  end

  def stop
    EM.cancel_timer( @check_orders_timer )
    super
  end

  # Check if we should add/remove pool based on orders list and available hashrate in current pools.
  # Try to have minimum 3 pools, and at least our hashrate available in non full pools.
  def check_orders
    rsorted_pools = @pools.sort.reverse
    available_pool_hashrate = rsorted_pools.map { |pool| (pool.max_hashrate || self.hashrate*2) - pool.hashrate }.sum
    waiting_orders = Order.uncomplete.sort - rsorted_pools.map(&:order) # if any not started yet
    return if waiting_orders.empty?
    best_waiting_price = waiting_orders.last.price
    # If there is an order more profitable than the worst pool launched
    if ! @pools.empty? && best_waiting_price > rsorted_pools.last.profitability
      log.verbose "new best price, add new pool"
      add_pool( waiting_orders.last ).on('started') { check_orders }
    # if there is not enough available pool waiting for hashrate, add the most profitable
    elsif @pools.size < 3 || available_pool_hashrate < self.hashrate
      log.verbose "not enough hashrate available, add new pool"
      add_pool( waiting_orders.last ).on('started') { check_orders }
    # if there is too much available pool waiting for hashrate, remove the less profitable pool
    elsif @pools.size > 3 && self.hashrate < available_pool_hashrate - ((rsorted_pools[-1].max_hashrate || self.hashrate*2) - rsorted_pools[-1].hashrate)
      log.verbose "too much hashrate available, delete last pool"
      delete_pool( rsorted_pools[-1] )
      rsorted_pools[-1].on( 'stopped' ) { check_orders }
    end
  rescue => err
    log.error "#{err}" #\n" + err.backtrace[0..5].join("\n")
  end

  def add_pool( obj )
    pool = obj.kind_of?( Order ) ? obj.pool : obj
    pool.on( 'done' ) { delete_pool( pool ) }
    super( pool )
  rescue => err
    log.error "#{err}"#\n" + err.backtrace[0...5].join("\n")
    nil
  end


  #############################################################################
  
  def on_authorize worker, req
    options = req.params[1] # in password field
    
    if options && options =~ /min_price:(\d+\.\d+)/
      min_price = BigDecimal( $~[1] )
    else
      min_price = nil
    end

    if min_price && worker.pool.profitability < min_price
      return req.respond( false )
    else
      super
      worker.model.user.min_price = min_price if min_price.present?
    end
  end

  #############################################################################

  def choose_pool_for_new_worker
    return @current_pool if @current_pool
    @pools.select(&:authentified).sort.delete_if { |pool| pool.max_hashrate && (pool.max_hashrate <= pool.hashrate) }.last
  end

  # Put all workers in most profitable pool, in pool limits, older first in case of equality.
  def balance_workers
    return if self.workers.empty? || @pools.size <= 1

    rsorted_pools = @pools.select(&:authentified).sort.reverse
    to_move_workers = []
    rsorted_pools.each_with_index do |pool,i|
      missing_hashrate = pool.max_hashrate && (pool.max_hashrate - pool.hashrate) || Float::INFINITY
      if missing_hashrate > 0 && ! to_move_workers.empty?
        to_move_workers.each do |w| w.pool = pool end
        to_move_workers.clear
        redo
      elsif missing_hashrate > 0
        res = get_workers( rsorted_pools[i+1..-1], missing_hashrate )
        log.info "[#{pool.name}] can add #{missing_hashrate / 10**6} MH, got #{res.last.mhash} MH for #{res.first.size} workers"
        res.first.each do |w| w.pool = pool end
      else
        res = get_workers_from( pool, -missing_hashrate )
        to_move_workers += res.first
      end
    end
    puts "must disconnect #{to_move_workers.size} workers" if ! to_move_workers.empty?
  rescue => err
    log.error "Error during workers balance : #{err}\n" + err.backtrace[0..5].join("\n")
  end

  #############################################################################

  def to_s
    s = StringIO.new
    @pools.sort.reverse.each do |pool|
      s.puts pool
    end
    s.string
  end
end
