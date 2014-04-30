# -*- encoding : utf-8 -*-

require 'test_helper'
require 'json'

require "protocol/stratum"

class Stratum::ServerTest < ActiveSupport::TestCase

  setup do
    get_em_mutex()
  end
  teardown do
    EM.next_tick { EM.stop_event_loop }
  end

  def test_connection
    t = 0
    host, port = "localhost", 8765
    server, client = Stratum::Server.new( host, port ), nil
    start_called = stop_called = false
    connect_called = disconnect_called = false

    server.on( 'started' ) do start_called = true end
    server.on( 'stopped' ) do stop_called = true end
    server.on( 'connect' ) do |cxn| connect_called = true end
    server.on( 'disconnect' ) do disconnect_called = true end

    EM.next_tick do server.start end

    EM.add_timer(0.01) do client = Stratum::Client.new( host, port ); client.connect end
    EM.add_timer(0.02) do client.close end
    EM.add_timer(0.03) do server.stop end

    sleep(0.1)

    assert start_called
    assert connect_called
    assert disconnect_called
    assert stop_called
  end

  def test_request
    host, port = "localhost", 8766
    server, client = Stratum::Server.new( host, port ), nil
    request_called = subscribe_called = subscribed_called = false
    first_asserts_passed = second_asserts_passed = false
    
    server.on( 'error' ) do |cxn, err| puts err end
    server.on( 'request' ) do |cxn, req|
      # assert_kind_of ServerHandler, cxn
      # assert_kind_of Rpc::Request, req
      request_called = true
    end
    server.on( 'mining.subscribe' ) do |cxn, req|
      # assert_kind_of ServerHandler, cxn
      # assert_kind_of Rpc::Request, req
      req.respond true
      subscribe_called = true
    end

    EM.next_tick do server.start end

    EM.add_timer( 0.01 ) do
      client = Stratum::Client.new( host, port )
      client.connect
    end
    EM.add_timer( 0.02 ) do
      client.mining.subscribe do |resp|
        # assert_kind_of Rpc::Response, resp
        subscribed_called = true
      end
    end

    sleep( 0.3 )

    assert request_called
    assert subscribe_called
    assert subscribed_called
    
    server.stop
  end
end
