# -*- encoding : utf-8 -*-

require 'test_helper'

require "protocol/stratum"

class Stratum::HandlerTest < MiniTest::Unit::TestCase

  class FakeConnection
    include Stratum::Handler
    def initialize
      post_init
    end
  end

  def setup
    @cxn = FakeConnection.new
    @request = Rpc::Request.new(@cxn, "mining.authorize", ["user", "password"], 1)
  end

  def test_validate_request
    # Everything is OK
    @cxn.validate_request @request

    # Error
    assert_raises Rpc::MethodNotFound do
      request = @request.dup
      request.instance_variable_set :@method, "authorize"
      @cxn.validate_request request
    end
  end
end
