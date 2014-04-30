# -*- encoding : utf-8 -*-

require 'core_extensions'
require "protocol/stratum"

require_relative './proxy_pool'

# using CoreExtensions

#
# The RentPool connect to an other distant pool.
# It forwards jobs to workers and shares to the distant pool.
# It acts as a big worker for the distant pool.
#
# Signals:
#   done
#
class RentPool < ProxyPool
  include Loggable
  include Listenable

  attr_reader :order, :total_hash, :max_hashrate

  def initialize( order )
    raise "Cannot start a pool with done order." if order.done?
    super( order.uri, name: order.pool_name )
    @order = order
    @max_hashrate = order.limit && order.limit.mhash
    log.info "[#{name}] max_hashrate=#{order.limit} MHs, hash_to_do=#{@order.hash_to_do.to_ghash} GH, prof=#{order.price}" if @order.price > Order::PRICE_MIN
  end

  def start
    order.set_running( true )
    super
  end

  def stop
    super
    order.set_complete if done?
    order.set_running( false )
  end

  def submit worker, req
    share = super
    return nil if share.nil?

    share.order = order
    share.save!
    if share.valid_share? && @order.price > Order::PRICE_MIN # TODO: remove last test. For debug purpose
      order.hash_done += MiningHelper.difficulty_to_nb_hash( share.difficulty )
      order.save!
    end
    log.info "total_hash is now #{order.hash_done}. >= #{order.hash_done >= @order.hash_to_do} ?" if @order.price > Order::PRICE_MIN # For debug purpose
    emit('done') if done?

    share
  end

  def done?
    @order.hash_done >= @order.hash_to_do
  end

  def profitability
    if self.done?
      0.0
    else
      order.price
    end
  end

  def <=>( o )
    return super if ! o.kind_of?( RentPool )
    @order <=> o.order
  end

  # Progress in %
  # => float 
  def progress
    (100.0 * order.hash_done / @order.hash_to_do).round(0)
  end

  def to_s
    super.gsub(/\b(Proxy)?Pool\b/, "RentPool").sub( %r{BTC/MHs/day}, "BTC/MHs/day, #{progress} %" )
  end
end # RentPool
