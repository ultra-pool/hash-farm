require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "it should verify username and host before validation" do
    order = Order.new( user_id: 1, url: "stratum+tcp://www.domain.com:3333", username: "user", password: "pass", pay: 0.01, price: 0.01 )
    assert order.save

    order = Order.new( user_id: 1, url: "stratum+tcp://user:pass@www.domain.com:3333", pay: 0.01, price: 0.01 )
    assert order.save

    order = Order.new( user_id: 1, url: "stratum+tcp://www.domain.com:3333", pay: 0.01, price: 0.01 )
    refute order.save

    order = Order.new( user_id: 1, url: "stratum+tcp://in(valid)_[host]:3333", username: "user", password: "pass", pay: 0.01, price: 0.01 )
    refute order.save
  end
end
