# -*- encoding : utf-8 -*-

require 'test_helper'
require 'ostruct'

require "pool/pool"
require "multicoin_pools/pool_picker"

class PoolTest < ActiveSupport::TestCase
  setup do
    @pool = Pool.new("pool_test")
  end

  test "it should initialize" do
    assert_kind_of Enumerable, @pool.workers
    assert_kind_of Numeric , @pool.desired_share_rate_per_worker
  end

  test "it should calculate global hashrate" do
    assert_equal 0, @pool.hashrate

    @pool.workers << OpenStruct.new(hashrate: 10**5)
    @pool.workers << OpenStruct.new(hashrate: 10**6)
    @pool.workers << OpenStruct.new(hashrate: 5*10**5)
    assert_equal 16 * 10**5, @pool.hashrate
  end

  test "it should update_desired_share_rate_per_worker" do
    assert_equal Pool::DESIRED_GLOBAL_SHARE_RATE, @pool.desired_share_rate_per_worker

    @pool.workers << OpenStruct.new(hashrate: 10**5)
    @pool.update_desired_share_rate_per_worker
    assert_equal Pool::DESIRED_GLOBAL_SHARE_RATE / 1, @pool.desired_share_rate_per_worker

    @pool.workers << OpenStruct.new(hashrate: 10**6)
    @pool.update_desired_share_rate_per_worker
    assert_equal Pool::DESIRED_GLOBAL_SHARE_RATE / 2, @pool.desired_share_rate_per_worker

    @pool.workers << OpenStruct.new(hashrate: 5*10**5)
    @pool.update_desired_share_rate_per_worker
    assert_equal Pool::DESIRED_GLOBAL_SHARE_RATE / 3, @pool.desired_share_rate_per_worker
  end

  test "it should compute profitability" do
    # No profitability return nil
    assert_equal 0.0, Pool.new("profit_1").profitability
    # Profitability set as a Number
    assert_equal 0.1, Pool.new("profit_2", profitability: 0.1).profitability
    # Profitability set as a Callable
    pool = Pool.new("profit_3", profitability: -> { PoolPicker.profitability_of('middlecoin') } )
    t = Time.now
    assert_kind_of Float, pool.profitability
    assert_operator Time.now - t, :>, 0.1
    # Recall doesn't recompute, profitability is still valide.
    t = Time.now
    assert_kind_of Float, pool.profitability
    assert_operator Time.now - t, :<, 0.01
  end

  test "it should compute diff" do skip end
  test "it should adjust diff" do skip end
  test "it should subscribe" do skip end
  test "it should authorize anonymous user" do skip end
  test "it should authorize anonymous worker" do skip end
  test "it should authorize worker" do skip end
  test "it should submit wrong share" do skip end
  test "it should submit pool share" do skip end
  test "it should submit block" do skip end
end
