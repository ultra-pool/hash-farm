# -*- encoding : utf-8 -*-
require 'test_helper'

class TransferTest < ActiveSupport::TestCase
  setup do
    @txid = "d1e21e283d5e917b2ddd01c0a579d41d4b0e60062890f1958485ea86b3f24743"
    @vout = 0
    @barbu = users(:barbu)
    @toto = users(:toto)
    @amount = 0.42
    @transfer = Transfer.new( sender: @barbu, recipient: @toto, amount: @amount )
  end

  test "it should assert amount is present" do
    assert Transfer.new( sender: @barbu, recipient: @toto, amount: @amount ).valid?
    assert Transfer.new( sender: @barbu, recipient: @toto, amount: 0 ).invalid?
    assert Transfer.new( sender: @barbu, recipient: @toto, amount: 10**9 ).invalid?
    assert Transfer.new( sender: @barbu, recipient: @toto, amount: nil ).invalid?
    assert Transfer.new( sender: @barbu, recipient: @toto, amount: "toto" ).invalid?
    assert Transfer.new( sender: @barbu, recipient: @toto ).invalid?
  end

  test "it should check txid format" do
    assert Transfer.new( sender: @barbu, txid: @txid, vout: @vout, amount: @amount ).valid?
    assert Transfer.new( sender: @barbu, txid: 1.2, vout: @vout, amount: @amount ).invalid?
    assert Transfer.new( sender: @barbu, txid: "toto", vout: @vout, amount: @amount ).invalid?
    assert Transfer.new( sender: @barbu, txid: "2ddd01c0a579d41d4b0e60062890f1958485ea86b3f24743", vout: @vout, amount: @amount ).invalid?
    assert Transfer.new( sender: @barbu, txid: "XXe21e283d5e917b2ddd01c0a579d41d4b0e60062890f1958485ea86b3f24743", vout: @vout, amount: @amount ).invalid?
  end


  test "it should check vout is with txid" do
    assert Transfer.new( sender: @barbu, txid: @txid, vout: @vout, amount: @amount ).valid?
    assert Transfer.new( sender: @barbu, txid: @txid, vout: 1.2, amount: @amount ).invalid?
    assert Transfer.new( sender: @barbu, txid: @txid, vout: -1, amount: @amount ).invalid?
    assert Transfer.new( sender: @barbu, txid: @txid, amount: @amount ).invalid?
    assert Transfer.new( sender: @barbu, recipient: @toto, vout: @vout, amount: @amount ).invalid?
  end

  test "it should assert_2_and_only_2_of_sender_recipient_and_txid_are_present" do
    assert Transfer.new( sender: @barbu, recipient: @toto, amount: @amount ).valid?
    assert Transfer.new( sender: @barbu, txid: @txid, vout: @vout, amount: @amount ).valid?
    assert Transfer.new( recipient: @barbu, txid: @txid, vout: @vout, amount: @amount ).valid?

    assert Transfer.new( sender: @barbu, amount: @amount ).invalid?
    assert Transfer.new( recipient: @toto, amount: @amount ).invalid?
    assert Transfer.new( txid: @txid, vout: @vout, amount: @amount ).invalid?
    assert Transfer.new( sender: @barbu, recipient: @toto, txid: @txid, vout: @vout, amount: @amount ).invalid?
  end

  test "it should scope from" do
    tfs = Transfer.from( @barbu )
    # assert Transfer.all.all? { |tf| tf.valid? || puts( tf.errors.inspect ) }
    assert_equal 2, tfs.size
    assert tfs.all? { |tf| tf.sender == @barbu }
  end

  test "it should scope to" do
    tfs = Transfer.to( @toto )
    assert_equal 2, tfs.size
    assert tfs.all? { |tf| tf.recipient == @toto }, tfs.map(&:inspect).join("\n")
  end

  test "it should scope of" do
    tfs = Transfer.of( @barbu )
    assert_equal 3, tfs.size
    assert tfs.all? { |tf| tf.sender == @barbu || tf.recipient == @barbu }

    tfs = Transfer.of( @toto )
    assert_equal 3, tfs.size
    assert tfs.all? { |tf| tf.sender == @toto || tf.recipient == @toto }
  end

  test "it should compute balance" do
    assert_equal 0, Transfer.balance( @barbu )
    assert_equal 0.2, Transfer.balance( @toto )
  end

  test "it should get credits" do
    assert_equal 1, Transfer.credits( @barbu ).size
    assert_equal 0, Transfer.credits( @toto ).size
  end

  test "it should get payouts" do
    assert_equal 0, Transfer.payouts( @barbu ).size
    assert_equal 1, Transfer.payouts( @toto ).size
  end
end
