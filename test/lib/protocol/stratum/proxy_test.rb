# -*- encoding : utf-8 -*-

require 'test_helper'
require 'json'

require "protocol/stratum"

class Stratum::ProxyTest < ActiveSupport::TestCase

  setup do
    @our_port = rand(10000)+20000
    @pool_port = rand(10000)+10000
    @pool = Stratum::Server.new( "localhost", @pool_port )
    get_em_mutex()
    EM.next_tick do @pool.start end
  end

  teardown do
    EM.next_tick do
      @pool.stop
      EM.stop
    end
  end

  test "it should start and stop correctly" do
    proxy = Stratum::Proxy.new( "localhost", @our_port, "localhost", @pool_port )
    t = 0
    started, stopped = false, false

    proxy.on( 'start' ) do started = true end
    proxy.on( 'stop' ) do stopped = true end

    EM.next_tick do proxy.start end
    EM.add_timer( 0.01 ) do proxy.stop end
    sleep(0.2)

    assert started
    assert stopped
  end

  test "it should create client on connection" do
    proxy = Stratum::Proxy.new( "localhost", @our_port, "localhost", @pool_port )
    client1, client2, t = nil, nil, 0
    worker_in_pool = false

    @pool.on( 'connect' ) do worker_in_pool = true end
    @pool.on( 'disconnect' ) do worker_in_pool = false end
    @pool.on( 'cxn_in.disconnect' ) do worker_in_pool = false end
    @pool.on( 'cxn_out.disconnect' ) do worker_in_pool = false end

    EM.next_tick do
      proxy.start
    end

    EM.add_timer( t += 0.01 ) do
      client1 = Stratum::Client.new( "localhost", @our_port )
      client2 = Stratum::Client.new( "localhost", @our_port )
      client1.connect
      client2.connect
    end
    sleep(0.2)
    
    assert_equal 2, proxy.clients.size
    assert worker_in_pool

    EM.next_tick do client1.close end
    sleep( 0.1 )

    assert_equal 1, proxy.clients.size
    refute worker_in_pool

    EM.next_tick do proxy.stop end
    sleep( 0.1 )

    assert proxy.clients.size == 0 || proxy.clients.all? { |_,c| c.closed? }
    refute worker_in_pool
  end

  test "it should transmit request and response to each one" do
    proxy = Stratum::Proxy.new( "localhost", @our_port, "localhost", @pool_port )
    client, connexion, t = nil, nil, 0
    pool_received_req = proxy_received_req = client_received_resp = client_received_notif = false

    @pool.on( 'mining.authorize' ) do |cxn, req|
      pool_received_req = true
      connexion = cxn
      req.respond( true )
    end
    proxy.on( 'request' ) do |cxn, req|
      proxy_received_req = true if req.method == "mining.authorize"
    end

    EM.next_tick do
      proxy.start
    end

    EM.add_timer( t += 0.01 ) do
      client = Stratum::Client.new( "localhost", @our_port )
      client.on( 'mining.set_difficulty' ) do client_received_notif = true end
      client.on( 'error' ) do |error| puts "client.error #{error}" end
      client.on( 'mining.error' ) do |error| puts "client.error #{error}" end
      client.connect
    end

    sleep( 0.1 )

    assert_equal 1, proxy.clients.size

    EM.next_tick do
      client.mining.authorize("barbu", "toto") do |resp|
        client_received_resp = true
      end
    end

    sleep( 0.5 )

    assert proxy_received_req
    assert pool_received_req
    assert client_received_resp

    EM.next_tick do
      connexion.mining.set_difficulty( 42 )
    end
    
    sleep( 0.5 )

    assert client_received_notif
  end
end