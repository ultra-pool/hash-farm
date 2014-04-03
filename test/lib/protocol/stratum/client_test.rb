# -*- encoding : utf-8 -*-

require 'test_helper'
require 'json'

require "protocol/stratum"

class Stratum::ClientTest < ActiveSupport::TestCase
  setup do
    @host = "localhost"
    @port = rand(10000) + 30000
    get_em_mutex()
    @server = TCPServer.new( @host, @port )
    @client = Stratum::Client.new( @host, @port )
    @client.connect
    @cxn = @server.accept
  end
  teardown do
    EM.stop
  end

  test "it should work" do
    # Client subscribe
    response_called, id = false, nil
    disconnected_self = disconnected_handler = false

    @client.on( 'disconnect' ) do
      disconnected_self = true
    end
    Rpc::Handler.on( 'disconnect' ) do |hdlr|
      disconnected_handler = (hdlr == @client)
    end

    @client.mining.subscribe do |resp|
      response_called = true
      assert_equal id, resp.id
      assert_equal true, resp.result
    end

    # Server read and resp
    sleep( 0.1 )
    req = JSON.parse( @cxn.read_nonblock(4096).chop )
    assert_kind_of Hash, req
    id = req["id"]
    @cxn.write( {"id" => id, "result" => true}.to_json + "\n" )

    # Assert subscribe block is called
    sleep( 0.1 )
    assert response_called, "async test, fail sometimes"

    # assert disconnected is called
    @client.close
    assert disconnected_self
    assert disconnected_handler
  end
end
