# -*- encoding : utf-8 -*-

require 'test_helper'

require "pool/proxy_pool"
require "protocol/stratum/server"

class ProxyPoolTest < ActiveSupport::TestCase

  setup do
    # Initialize distant pool
    get_em_mutex()
    init_dest_pool
    EM.next_tick { @dist_pool.start }
    sleep(0.1)
  end

  teardown do
    EM.next_tick { @dist_pool.stop }
    EM.add_timer(0.1) { EM.stop_event_loop }
  end

  test 'it should start and fail on subscribe' do
    proxy_pool = ProxyPool.new( "localhost", @port, @username, @password )
    # proxy_pool.on( 'error' ) do |*params| p params end

    started = stopped = false
    error = false

    proxy_pool.on('error') do error = true end
    proxy_pool.on('started') do started = true end
    proxy_pool.on('stopped') do stopped = true end

    EM.next_tick do
      proxy_pool.version = "n_importe_quoi"
      proxy_pool.start
    end

    EM.add_timer(0.1) do
      proxy_pool.stop
    end

    sleep(0.2)

    assert error
    refute started
    assert stopped
  end

  test 'it should start and fail on authorize' do
    proxy_pool = ProxyPool.new( "localhost", @port, "wrong_log", "wrong_pass" )
    # proxy_pool.on( 'error' ) do |*params| p params end

    started = stopped = false
    error = false

    proxy_pool.on('error') do error = true end
    proxy_pool.on('started') do started = true end
    proxy_pool.on('stopped') do stopped = true end

    EM.run do proxy_pool.start end
    sleep(0.5)

    EM.run do proxy_pool.stop end
    sleep(0.1)

    assert error
    refute started
    assert stopped
  end

  test 'it should start correctly' do
    proxy_pool = ProxyPool.new( "localhost", @port, @username, @password )
    proxy_pool.on( 'error' ) do |*params| p params end

    started = stopped = false
    error = false

    proxy_pool.on('error') do error = true end
    proxy_pool.on('started') do started = true end
    proxy_pool.on('stopped') do stopped = true end

    EM.run do proxy_pool.start end
    sleep(0.5)

    EM.run do proxy_pool.stop end
    sleep(0.1)

    refute error
    assert started
    assert stopped
  end

  test 'it should received set_difficulty and notify' do
    proxy_pool = ProxyPool.new( "localhost", @port, @username, @password )
    proxy_pool.on( 'error' ) do |*params| p params end

    proxy_pool.expects( :on_pool_set_difficulty ).once
    proxy_pool.expects( :on_pool_notify ).once

    EM.next_tick do proxy_pool.start end
    sleep(0.5)

    EM.next_tick do proxy_pool.stop end
  end

  test 'it should return default profitability' do
    proxy_pool = ProxyPool.new( "localhost", @port, @username, @password )
    assert_equal 0.0, proxy_pool.profitability
  end

  test 'it should return given profitability' do
    proxy_pool = ProxyPool.new( "localhost", @port, @username, @password, profitability: 0.0042 )
    assert_equal 0.0042, proxy_pool.profitability
  end

  test 'it should return given callable profitability' do
    proxy_pool = ProxyPool.new( "localhost", @port, @username, @password, profitability: -> { 0.00314 } )
    assert_equal 0.00314, proxy_pool.profitability
  end

  test 'it should retrieve profitability on the website' do
    profitability = {
      profitability_url: "http://coinshift.com//",
      profitability_path: ".panel-heading:contains('24h') + .stats-box h1",
    }
    proxy_pool = ProxyPool.new( "localhost", @port, @username, @password, profitability )
    assert_kind_of Float, proxy_pool.profitability
  end

  test "it should compute diff" do skip end
  test "it should subscribe" do skip end
  test "it should submit dist pool share" do skip end
  test "it should clean_previous_jobs" do skip end

  ######################################

  def init_dest_pool
    @port = rand(10000)+10000
    @username, @password = "barbu", "toto"
    @dist_pool = Stratum::Server.new( "localhost", @port )
    # @dist_pool.on( 'request' ) do |cxn, req| puts "dist_pool: #{req}" end
    # @dist_pool.on( 'notification' ) do |cxn, notif| puts "dist_pool: #{notif}" end
    @dist_pool.on('mining.subscribe') do |cxn, req|
      if req.params.empty?
        req.respond [["uuid_1", "mining.notify", "uuid_2", "mining.set_difficulty"], "f0f01f1f", 4]
      else
        req.error Rpc::InvalidParams.new(extra_msg: "Unknow param", id: req.id)
      end
    end
    @dist_pool.on('mining.authorize') do |cxn, req|
      login_status = req.params == [@username, @password]
      req.respond login_status
      next unless login_status
      cxn.mining.set_difficulty 42
      cxn.mining.notify( *generate_job )
    end
    @dist_pool.on('mining.submit') do |cxn, req|
      req.respond req.params
    end
  end

  def generate_job
    ["job_id", "f32a1662d3f5bd45181d6e6b4fe7bc5627bec8f383ba94e9dbf2823962d9192d", "coinb1", "coinb2", [], "00000002", "1c2ac4af", "504e86b9", false]
  end
end
