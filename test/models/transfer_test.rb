require 'test_helper'

class TransferTest < ActiveSupport::TestCase
  setup do
    @txid = "d1e21e283d5e917b2ddd01c0a579d41d4b0e60062890f1958485ea86b3f24743"
    @vout = 0
    @barbu = users(:barbu)
    @mv = users(:mv)
    @amount = 0.42
    @transfer = Transfer.new( sender: @barbu, recipient: @mv, amount: @amount )
  end

  test "it should assert amount is present" do
    assert Transfer.new( sender: @barbu, recipient: @mv, amount: @amount ).valid?
    assert Transfer.new( sender: @barbu, recipient: @mv, amount: 0 ).invalid?
    assert Transfer.new( sender: @barbu, recipient: @mv, amount: 10**9 ).invalid?
    assert Transfer.new( sender: @barbu, recipient: @mv, amount: nil ).invalid?
    assert Transfer.new( sender: @barbu, recipient: @mv, amount: "toto" ).invalid?
    assert Transfer.new( sender: @barbu, recipient: @mv ).invalid?
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
    assert Transfer.new( sender: @barbu, recipient: @mv, vout: @vout, amount: @amount ).invalid?
  end

  test "it should assert_2_and_only_2_of_sender_recipient_and_txid_are_present" do
    assert Transfer.new( sender: @barbu, recipient: @mv, amount: @amount ).valid?
    assert Transfer.new( sender: @barbu, txid: @txid, vout: @vout, amount: @amount ).valid?
    assert Transfer.new( recipient: @barbu, txid: @txid, vout: @vout, amount: @amount ).valid?

    assert Transfer.new( sender: @barbu, amount: @amount ).invalid?
    assert Transfer.new( recipient: @mv, amount: @amount ).invalid?
    assert Transfer.new( txid: @txid, vout: @vout, amount: @amount ).invalid?
    assert Transfer.new( sender: @barbu, recipient: @mv, txid: @txid, vout: @vout, amount: @amount ).invalid?
  end
end
