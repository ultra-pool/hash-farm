# -*- encoding : utf-8 -*-

require 'test_helper'

require "protocol/rpc"
require "protocol/stratum/mining_handler"

class Stratum::MiningTest < MiniTest::Unit::TestCase

  def setup
    @mining = Stratum::MiningHandler.new(nil)
    @request = Rpc::Request.new(@cxn, "mining.authorize", ["user", "password"], 1)
  end

  def test_validate_request
    @mining.validate_request @request

    assert_raises Rpc::InvalidParams do
      request = @request
      request.instance_variable_set :@method, "submit"
      @mining.validate_request request
    end
  end
end
