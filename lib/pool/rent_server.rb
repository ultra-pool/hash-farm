# -*- encoding : utf-8 -*-

require_relative './main_server'

#
class RentServer < MainServer
  include Loggable

  CHECK_ORDERS_POOL_EVERY = 1.minute

  def init_pools
    add_rent_from_proxy_pool( @config.proxy_pools.first )
    log.verbose "#{@pools.size} rent_pools created."
  end

  def start
    @check_orders_timer = EM.add_periodic_timer( CHECK_ORDERS_POOL_EVERY ) { check_orders }
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
    available_pool_hashrate = rsorted_pools.map { |pool| pool.max_hashrate - pool.hashrate }.sum
    waiting_orders = Order.non_complete.waiting.sort
    return if waiting_orders.empty?
    best_waiting_price = waiting_orders.last.price
    # If there is an order more profitable than the worst pool launched
    if best_waiting_price > rsorted_pools.last.profitability
      add_rent_pool waiting_orders.last
    # if there is not enough available pool waiting for hashrate, add the most profitable
    elsif available_pool_hashrate < self.hashrate || @pools.size < 3
      add_rent_pool waiting_orders.last
    # if there is too much available pool waiting for hashrate, remove the less profitable pool
    else
      available_pool_hashrate = rsorted_pools[0...-1].map { @pools.max_hashrate - @pools.hashrate }.sum
      if available_pool_hashrate > self.hashrate
        delete_rent_pool rsorted_pools[-1]
      else
        return
      end
    end
    check_orders
  rescue => err
    puts err, err.backtrace[0..5].join("\n")
  end

  def add_rent_pool( order )
    pool = order.pool
    pool.on( 'done' ) { delete_rent_pool( pool ) }
    add_pool( pool )
  rescue => err
    puts err, err.backtrace[0...5].join("\n")
    nil
  end

  def delete_rent_pool( pool )
    super
  end

  def add_rent_from_proxy_pool( name )
    p = MulticoinPool[name]
    order = Order.new(user_id: 1, url: p.url, username: p.account, password: p.password || 'x', pay: Order::PAY_MIN, price: Order::PRICE_MIN)
    add_rent_pool( order )
  rescue => err
    puts err, err.backtrace[0...5].join("\n")
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
    @pools.sort.delete_if { |pool| pool.max_hashrate <= pool.hashrate }.last
  end

  def balance_workers
    return if self.workers.empty? || @pools.size <= 1
    fill_most_profitable_first
  rescue => err
    log.error "Error during workers balance : #{err}\n" + err.backtrace[0..5].join("\n")
  end

  #############################################################################

  # Put all workers in most profitable pool, in pool limits, older first in case of equality.
  def fill_most_profitable_first
    rsorted_pools = @pools.sort.reverse
    rsorted_pools.each_with_index do |pool,i|
      missing_hashrate = pool.max_hashrate - pool.hashrate
      res = get_workers( rsorted_pools[i+1..-1], missing_hashrate )
      log.info "[#{pool.name}] can add #{missing_hashrate} MH, got #{res.last} MH for #{res.first.size} workers"
      res.first.each do |w| w.pool = pool end
    end
  end

  def to_s
    s = StringIO.new
    @pools.sort.reverse.each do |pool|
      s.puts pool
    end
    s.string
  end
end
