# -*- encoding : utf-8 -*-

require 'test_helper'
require "mocha/mini_test"

require "protocol/rpc"

class Rpc::HandlerTest < MiniTest::Unit::TestCase

  include Rpc

  Rpc::Handler.disable_logs

  class FakeConnection
    include Rpc::Handler
    def initialize
      post_init
    end
  end

  def setup
    @connection = FakeConnection.new
    @request = {
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "mining.authorize",
      "params" => ["user", "password"]
    }
  end

  def test_receive_request
    listener_called = false

    @connection.on('request') do |req|
      listener_called = true
      assert_equal @request["method"], req.method
      assert_equal @request["id"], req.id
      assert_equal @request["params"], req.params
    end

    @connection.receive_request @request

    assert listener_called
  end

  def test_receive_json
    stub_send_data
    stub_receive_request

    result = @connection.receive_json @request
    assert_equal @request, result, "Problem with stub ? result = #{result.inspect}"

    command = @request.dup
    command.delete("id")
    result = @connection.receive_json @request
    assert_equal @request, result, "Problem with stub ? result = #{result.inspect}"

    command = @request.dup
    command.delete("params")
    result = @connection.receive_json @request
    assert_equal @request, result, "Problem with stub ? result = #{result.inspect}"

    command = @request.dup
    command["params"] = {"name" => "user", "password" => "password"}
    result = @connection.receive_json @request
    assert_equal @request, result, "Problem with stub ? result = #{result.inspect}"

    assert_raises Rpc::InvalidRequest do
      @connection.receive_json []
    end

    assert_raises Rpc::InvalidRequest do
      @connection.receive_json ""
    end

    @connection.skip_jsonrpc_field = true

    command = @request.dup
    command.delete("jsonrpc")
    @connection.receive_json command

    @connection.skip_jsonrpc_field = false

    assert_raises Rpc::InvalidRequest do
      @connection.receive_json command
    end

    assert_raises Rpc::InvalidRequest do
      command = @request.dup
      command["jsonrpc"] = 2.0
      @connection.receive_json command
    end

    assert_raises Rpc::InvalidRequest do
      command = @request.dup
      command["jsonrpc"] = "1.0"
      @connection.receive_json command
    end

    assert_raises Rpc::InvalidRequest do
      command = @request.dup
      command.delete("method")
      @connection.receive_json command
    end

    assert_raises Rpc::InvalidRequest do
      command = @request.dup
      command["method"] = nil
      @connection.receive_json command
    end

    assert_raises Rpc::InvalidRequest do
      command = @request.dup
      command["method"] = []
      @connection.receive_json command
    end

    assert_raises Rpc::InvalidRequest do
      command = @request.dup
      command["id"] = []
      @connection.receive_json command
    end
  end

  def test_receive_line
    stub_send_data
    stub_receive_request
    stub_send_error

    @connection.receive_line @request.to_json

    # stub_send_error raise error instead of send it
    assert_raises Rpc::ParseError do
      @connection.receive_line "{42}"
    end
  end

  def test_receive_data_1
    stub_send_data
    stub_receive_request
    # stub_send_response
    # stub_send_error

    result = @connection.receive_data @request.to_json
    assert_kind_of Array, result
    assert_equal 1, result.size, "#{result}"
    
    result = @connection.receive_data ['{"jsonrpc":"2.0","id":2,"method":"test1"}','{"jsonrpc":"2.0","method":"module.test2","params":[]}'] * "\n" + "\n"
    assert_kind_of Array, result
    assert_equal 2, result.size
    assert_equal( {"jsonrpc"=>"2.0", "id" => 2, "method" => "test1"}, result.first.to_h )
    assert_equal( {"jsonrpc"=>"2.0", "method" => "module.test2", "params" => []}, result.last.to_h )

    result = @connection.receive_data '{"jsonrpc" => "2.0","id":2,"method":"test1"}{"jsonrpc" => "2.0","method":"module.test2","params":[]}' + "\n"
    assert_kind_of Array, result
    assert_equal 1, result.size
    assert_kind_of Rpc::ErrorResponse, result.last
    assert_kind_of Rpc::ParseError, result.last.error

    result = @connection.receive_data ['{"jsonrpc":"2.0","id":2,"method":"test1"}', '{"jsonrpc":"2.0","params":[]}'] * "\n" + "\n"
    assert_kind_of Array, result
    assert_equal 2, result.size
    assert_equal( {"jsonrpc" => "2.0", "id" => 2, "method" => "test1"}, result.first )
    assert_kind_of Rpc::ErrorResponse, result.last
    assert_kind_of Rpc::InvalidRequest, result.last.error

    result = @connection.receive_data ['{"jsonrpc":"2.0","params":[]}', '{"jsonrpc":"2.0","id":2,"method":"test1"}'] * "\n" + "\n"
    assert_kind_of Array, result
    assert_equal 2, result.size
    assert_kind_of Rpc::ErrorResponse, result.first
    assert_kind_of Rpc::InvalidRequest, result.first.error
    assert_equal( {"jsonrpc" => "2.0", "id" => 2, "method" => "test1"}, result.last.to_h )
  end

  def test_send_response
    stub_send_data

    resp1 = {"jsonrpc" => "2.0", "id" => 2, "result" => true}
    result = @connection.send_response true, 2
    assert_kind_of Rpc::Response, result
    assert_equal resp1, result.to_h

    resp2 = {"jsonrpc" => "2.0", "id" => 3, "error" => {"code" => -32700, "message" => "ParseError", "data" => {}}}
    result = @connection.send_response Rpc::ParseError.new, 3
    assert_kind_of Rpc::ErrorResponse, result
    assert_equal resp2, result.to_h
  end

  private

    def stub_receive_request( connection=@connection )
      connection.define_singleton_method(:receive_request) { |cmd| cmd }
    end

    def stub_send_response( connection=@connection )
      connection.define_singleton_method(:send_response) { |resp, id| resp }
    end

    def stub_send_error( connection=@connection )
      connection.define_singleton_method(:send_error) { |error, id=nil| raise error if error.kind_of?( Exception ); error }
    end

    def stub_send_data( connection=@connection )
      connection.define_singleton_method(:send_data) { |data|
        data
      }
    end
end
