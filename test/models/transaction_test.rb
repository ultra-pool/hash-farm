require 'test_helper'

class TransactionTest < ActiveSupport::TestCase
  setup do
    @balance_address = "mmcWox9YGisFKTnR6kbKjU7dZyLxqzAYuF"
    # @txid, @vout, @amount = @unspent.txid, @unspent.vout, @unspent.amount
  end

  test "it should not initialize without coin" do
    skip
    assert_raises RuntimeError do
      Transaction.new
    end
  end

  test "it should initialize with just coin" do
    skip
    tx = Transaction.new
    assert_equal @coin, tx.coin
    assert_equal [], tx.inputs
    assert_equal({}, tx.outputs)
  end

  test "it should initialize with hash of attributes" do
    skip
    inputs = [{txid: @txid, vout: @vout}]
    outputs = {"toto" => 42}
    tx = Transaction.new( inputs: inputs, outputs: outputs )

    assert_nil tx.txid
    assert_nil tx.ourid
    assert_nil tx.block
    assert_nil tx.raw
    assert_equal inputs, tx.inputs
    assert_equal outputs, tx.outputs
  end

  test "it should add input" do
    skip
    tx = Transaction.new
    tx.add_input( @txid, @vout, @amount )
    assert_equal 1, tx.inputs.size
    res_waited = {
      txid: @txid,
      vout: @vout,
      amount: @amount
    }
    assert_equal res_waited, tx.inputs.first
  end

  test "it should add output with address or user and sum for same addresses" do
    skip
    tx = Transaction.new
    assert tx.outputs.empty?

    tx.add_output( users(:barbu).payout_address , 10**6 )
    assert_equal 1, tx.outputs.size
    assert_equal 10**6, tx.outputs[users(:barbu).payout_address]

    tx.add_output( users(:one).payout_address , 10**7 )
    assert_equal 2, tx.outputs.size
    assert_equal 10**7, tx.outputs[users(:one).payout_address]
    assert_equal 10**6, tx.outputs[users(:barbu).payout_address]

    tx.add_output( users(:barbu), 10**6 )
    assert_equal 2, tx.outputs.size
    assert_equal 2 * 10**6, tx.outputs[users(:barbu).payout_address]
    assert_equal 10**7, tx.outputs[users(:one).payout_address]
  end

  test "it should compute total_input" do
    skip
    tx = Transaction.new
    tx.add_input( @txid, @vout, @amount )
    tx.add_output( users(:one), @amount / 3 )
    tx.add_output( users(:two), @amount / 2 )

    assert_equal @amount, tx.total_input
  end

  test "it should compute total_output" do
    skip
    tx = Transaction.new
    tx.add_input( @txid, @vout, @amount )
    tx.add_output( users(:one), @amount / 3 )
    tx.add_output( users(:two), @amount / 2 )

    assert_equal @amount * 5 / 6, tx.total_output
  end

  test "it should compute fess" do
    skip
    tx = Transaction.new
    tx.add_input( @txid, @vout, @amount )
    tx.add_output( users(:one), @amount / 3 )
    tx.add_output( users(:two), @amount / 2 )

    assert_equal (@amount / 6.0).ceil, tx.fees
  end

  test "it should get raw unsigned" do
    skip
    tx = Transaction.new

    raw = tx.get_raw_unsigned
    assert_kind_of String, raw
    assert_equal "01000000" + "00" + "00" + "00000000", raw

    btx = Bitcoin::Protocol::Tx.new( [raw].pack("H*") )
    assert_equal 0, btx.in.size
    assert_equal 0, btx.out.size

    tx.add_input( @txid, @vout, @amount )
    tx.add_output( users(:one), @amount / 4 )
    tx.add_output( users(:two), @amount * 3 / 4 )

    raw = tx.get_raw_unsigned
    assert_kind_of String, raw
    assert_operator (4 + 1 + 41 + 1 + 9 + 4) * 2, :<, raw.size
    assert_equal raw, tx.get_raw_unsigned, "Got two different raw unsigned transaction"

    tx = Bitcoin::Protocol::Tx.new( [raw].pack("H*") )
    assert_empty tx.in[0].script
  end

  test "it should get raw signed" do
    skip
    tx = Transaction.new
    tx.add_input( @txid, @vout, @amount )
    tx.add_output( users(:one), @amount / 4 )
    tx.add_output( users(:two), @amount * 3 / 4 )
    
    raw = tx.get_raw_signed
    # Get a new signature each time rpc.signrawtransaction is called, i don't know why.
    # So compute a different txid each time too.
    refute_equal tx.raw, raw, "Two equal signatures for a transaction, weird."

    assert_kind_of String, raw
    assert_operator raw.size, :>, (4 + 1 + 41 + 1 + 9 + 4) * 2

    tx = Bitcoin::Protocol::Tx.new( [raw].pack("H*") )
    refute_empty tx.in[0].script
  end

  test "it should compute ourid" do
    skip
    tx = Transaction.new
    tx.add_input( @txid, @vout, @amount )
    tx.add_output( users(:one), @amount / 4 )
    tx.add_output( users(:two), @amount * 3 / 4 )

    ourid = tx.get_ourid
    assert_kind_of String, ourid
    assert_equal 64, ourid.size # SHA256 hex encoded hash.

    tx = Transaction.new
    tx.add_output( users(:two), @amount * 3 / 4 )
    tx.add_output( users(:one), @amount / 4 )
    tx.add_input( @txid, @vout, @amount )

    assert_equal ourid, tx.get_ourid
  end

  test "it should check tx is valid" do
    skip
    tx = Transaction.new
    tx.add_input( @txid, @vout, @amount )
    tx.add_output( users(:one), @amount / 3 )
    tx.add_output( users(:two), @amount / 2 )

    assert tx.check_valid
    assert_raise RuntimeError do tx.check_valid(fix: tx.fees - 1) end
    assert_raise RuntimeError do tx.check_valid(percent: tx.fees.to_f / tx.total_input - 0.001) end

    tx.add_output( users(:one), @amount / 6 )
    assert tx.check_valid

    tx.add_output( users(:two), @amount / 6 )
    assert_raise RuntimeError do tx.check_valid end
  end

  test "it should send tx, get txid and ourid" do
    skip
    previous_count = Transaction.count
    tx = Transaction.new
    pool_tx = accounts(:pool).listunspent(1).first
    tx.add_input( pool_tx )
    balance_tx = accounts(:balances).listunspent(1).first
    tx.add_input( balance_tx )
    tx.add_output( accounts(:pool).address, pool_tx.amount - 5 * 10**3 )
    tx.add_output( accounts(:balances).address, balance_tx.amount - 5 * 10**3 )

    assert_equal 10**4, tx.fees
    tx.send_it!

    assert_kind_of String, tx.raw
    assert_kind_of String, tx.txid
    assert_kind_of String, tx.ourid
    assert_operator tx.raw.size, :>, (4 + 1 + 41 + 1 + 9 + 4) * 2
    assert_equal 32*2, tx.txid.size
    assert_equal 32*2, tx.ourid.size

    assert_equal previous_count + 1, Transaction.count

    refute_nil Transaction.find_by(txid: tx.txid)
  end
end
