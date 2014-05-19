# -*- encoding : utf-8 -*-
require 'test_helper'

class TransferTest < ActiveSupport::TestCase
  setup do
    @txid = "d1e21e283d5e917b2ddd01c0a579d41d4b0e60062890f1958485ea86b3f24743"
    @vout = 0
    @barbu = users(:barbu)
    @toto = miners(:toto)
    @amount = 0.42
    @order = orders(:one)
  end

  test "it should assert amount is present" do
    assert Transfer.new( user: @barbu, miner: @toto, amount: @amount, order: @order ).valid?
    assert Transfer.new( user: @barbu, miner: @toto, amount: 0.000000001, order: @order ).invalid?
    assert Transfer.new( user: @barbu, miner: @toto, amount: nil, order: @order ).invalid?
    assert Transfer.new( user: @barbu, miner: @toto, amount: "toto", order: @order ).invalid?
    assert Transfer.new( user: @barbu, miner: @toto, order: @order ).invalid?
  end

  test "it should check txid format" do
    t = Transfer.new( user: @barbu, txid: @txid, vout: @vout, amount: @amount )
    assert t.valid?, t.errors.messages
    t = Transfer.new( user: @barbu, txid: 1.2, vout: @vout, amount: @amount )
    assert t.invalid?, t.errors.messages
    t = Transfer.new( user: @barbu, txid: "toto", vout: @vout, amount: @amount )
    assert t.invalid?, t.errors.messages
    t = Transfer.new( user: @barbu, txid: "2ddd01c0a579d41d4b0e60062890f1958485ea86b3f24743", vout: @vout, amount: @amount )
    assert t.invalid?, t.errors.messages
    t = Transfer.new( user: @barbu, txid: "XXe21e283d5e917b2ddd01c0a579d41d4b0e60062890f1958485ea86b3f24743", vout: @vout, amount: @amount )
    assert t.invalid?, t.errors.messages
  end

  test "it should check vout is with txid" do
    assert Transfer.new( user: @barbu, txid: @txid, vout: @vout, amount: @amount ).valid?
    assert Transfer.new( user: @barbu, txid: @txid, vout: 1.2, amount: @amount ).invalid?
    assert Transfer.new( user: @barbu, txid: @txid, vout: -1, amount: @amount ).invalid?
    assert Transfer.new( user: @barbu, txid: @txid, amount: @amount ).invalid?
    assert Transfer.new( user: @barbu, miner: @toto, vout: @vout, amount: @amount ).invalid?
  end

  test "it should assert_2_and_only_2_of_user_miner_and_txid_are_present" do
    assert Transfer.new( user: @barbu, miner: @toto, amount: @amount, order: @order ).valid?
    assert Transfer.new( user: @barbu, txid: @txid, vout: @vout, amount: @amount ).valid?
    assert Transfer.new( miner: @toto, txid: @txid, vout: @vout, amount: @amount ).valid?

    assert Transfer.new( user: @barbu, amount: @amount ).invalid?
    assert Transfer.new( miner: @toto, amount: @amount ).invalid?
    assert Transfer.new( txid: @txid, vout: @vout, amount: @amount ).invalid?
    assert Transfer.new( user: @barbu, miner: @toto, txid: @txid, vout: @vout, amount: @amount ).invalid?
  end

  test "it should get credits" do
    assert_equal 2, Transfer.credits.size
  end

  test "it should get order_creations" do
    assert_equal 1, Transfer.order_creations.size
  end

  test "it should get mini_payouts" do
    assert_equal 3, Transfer.mini_payouts.size
  end

  test "it should get payouts" do
    assert_equal 1, Transfer.payouts.size
  end

  test "it should get order_cancels" do
    assert_equal 0, Transfer.order_cancels.size
  end

  test "it should get withdraws" do
    assert_equal 1, Transfer.withdraws.size
  end

  test "it should scope from" do
    tfs = Transfer.from( @barbu )
    # assert Transfer.all.all? { |tf| tf.valid? || puts( tf.errors.inspect ) }
    assert_equal 5, tfs.size
    assert tfs.all? { |tf| tf.user == @barbu }
  end

  test "it should scope to" do
    tfs = Transfer.to( @toto )
    assert_equal 3, tfs.size
    assert tfs.all? { |tf| tf.miner == @toto }, tfs.map(&:inspect).join("\n")
  end
end
