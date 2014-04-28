require 'test_helper'

class PayoutTest < ActiveSupport::TestCase
  setup do
    @payout_shares = shares( :payout1, :payout2, :payout3, :payout4, :payout5 )
    @accounts = [accounts(:balances)]
  end

  test "it should initialize with hash of attributes" do
    payout = Payout.new( transaction_id: transactions(:one), our_fees: 2 * 10**8, users_amount: 10**9 )

    assert_equal 2 * 10**8, payout.our_fees
    assert_equal 10**9, payout.users_amount
  end

  test "it should call add input and output to tx" do
    Transaction.any_instance.expects(:add_input).at_least( @accounts.size )
    Transaction.any_instance.expects(:add_output).twice # users one and two, but not barbu
    payout = Payout.new( @accounts, @payout_shares )
  end

  # test "it should add empty shares" do
  #   payout = Payout.new( @accounts, [] )
  #   assert_equal [], payout.shares
  # end

  test "it should compute fees" do
    payout = Payout.new( @accounts, @payout_shares )

    # Fees
    total = payout.tx.total_input
    assert_equal total * Payout::MINER_FEES, payout.miner_fees
    assert_in_delta total * Payout::OUR_FEES, payout.our_fees, @payout_shares.size
    assert_equal total - payout.miner_fees - payout.our_fees, payout.users_amount
  end

  test "it should update users and accounts balances" do
    barbu = users(:barbu)
    previous_barbu_balance = barbu.balance
    previous_balance = accounts(:balances)
    payout = Payout.new( @accounts, @payout_shares )
    refute payout.tx.outputs.key?( barbu.payout_address )
    assert_operator previous_barbu_balance, :<, users(:barbu).reload.balance

    assert payout.tx.outputs[ accounts(:balances).address ]
  end

  test "it should all initialize" do
    accounts = [accounts(:pool)]
    Account.any_instance.stubs(balance: 0.0)
    accounts.first.stubs(balance: 0.0, listunspent: [OpenStruct.new(txid: "fe295cf0f17d36324f7543f43aacca9c9cb4f43014b21243c1703373bc22d5b9", vout: 0, amount: 10**8)])

    shares = [
      Share.new(worker: workers(:barbu1), difficulty: 0.001, solution: "", our_result: true, pool_result: true, is_block: false),
      Share.new(worker: workers(:one), difficulty: 0.02, solution: "", our_result: true, pool_result: true, is_block: false),
      Share.new(worker: workers(:two), difficulty: 0.97, solution: "", our_result: true, pool_result: true, is_block: false),
      Share.new(worker: workers(:barbu1), difficulty: 0.001, solution: "", our_result: true, pool_result: true, is_block: false),
      Share.new(worker: workers(:one), difficulty: 0.01, solution: "", our_result: true, pool_result: true, is_block: false),
      Share.new(worker: workers(:two), difficulty: 0.998, solution: "", our_result: true, pool_result: true, is_block: false),
    ]
    
    assert_equal 0, users(:barbu).balance, "test must be adapted"
    assert_equal 0, users(:one).balance, "test must be adapted"
    assert_equal 0, users(:two).balance, "test must be adapted"

    waited_tt_input = 10**8
    waited_miner_fees = (10**8 * 0.005).to_i
    waited_our_fees = (10**8 * 0.02).to_i # crumbs
    waited_users_amount = waited_tt_input - waited_miner_fees - waited_our_fees
    waited_tt_output = waited_users_amount + waited_our_fees
    waited_total_diff = 2.0

    payout = Payout.new( accounts, shares )

    # Init accounts/inputs
    assert_equal 1, payout.tx.inputs.size
    assert_equal waited_tt_input, payout.tx.total_input

    # Init fees
    assert_equal waited_miner_fees, payout.miner_fees
    assert_equal waited_our_fees, payout.our_fees
    assert_equal waited_users_amount, payout.users_amount
    
    # Init shares/outputs
    assert_equal waited_tt_output, payout.tx.total_output
    assert_equal 2.0, payout.total_diff
    assert_equal 4, payout.tx.outputs.size, payout.tx.outputs.keys # one, two, fee, balance, 
    assert_equal [users(:one).payout_address, users(:two).payout_address, accounts(:fees).address, accounts(:balances).address].sort, payout.tx.outputs.keys.sort
    assert_equal 95940000, payout.tx.outputs[users(:two).payout_address]
    assert_equal 1462500, payout.tx.outputs[users(:one).payout_address]
    assert_equal waited_our_fees, payout.tx.outputs[accounts(:fees).address]
    assert_equal 97500, payout.tx.outputs[accounts(:balances).address]
    refute payout.tx.outputs.key?( users(:barbu).payout_address )

    # Change balances
    assert_equal 0, users(:one).reload.balance
    assert_equal 0, users(:two).reload.balance
    assert_equal 97500, users(:barbu).reload.balance
  end

  test "it should send_it!" do
    accounts = [accounts(:pool)]
    Account.any_instance.stubs(balance: 0.0)
    accounts.first.stubs(balance: 0.0, listunspent: [OpenStruct.new(txid: "fe295cf0f17d36324f7543f43aacca9c9cb4f43014b21243c1703373bc22d5b9", vout: 0, amount: 10**8)])

    shares = [
      Share.new(worker: workers(:barbu1), difficulty: 0.001, solution: "", our_result: true, pool_result: true, is_block: false),
      Share.new(worker: workers(:one), difficulty: 0.02, solution: "", our_result: true, pool_result: true, is_block: false),
      Share.new(worker: workers(:two), difficulty: 0.97, solution: "", our_result: true, pool_result: true, is_block: false),
      Share.new(worker: workers(:barbu1), difficulty: 0.001, solution: "", our_result: true, pool_result: true, is_block: false),
      Share.new(worker: workers(:one), difficulty: 0.01, solution: "", our_result: true, pool_result: true, is_block: false),
      Share.new(worker: workers(:two), difficulty: 0.998, solution: "", our_result: true, pool_result: true, is_block: false),
    ]
    
    payout = Payout.new( accounts, shares )

    payout.tx.stubs(send_it!: nil)
    assert shares.all? { |s| s.payout_id.nil? }
    payout.send_it!

    pay = Payout.find( payout.id )
    assert_equal payout.our_fees, pay.our_fees
    assert_equal payout.users_amount, pay.users_amount
    assert shares.all? { |s| s.payout_id == payout.id }
  end

  test "it should run payout" do
    Account.any_instance.expects(listunspent: []).times(4)
    Transaction.any_instance.expects(send_it!: nil).once
    payout = Payout.run
    assert_kind_of Payout, payout
    assert payout.shares.size.between?(3, 4), "payout.shares.size not in 3..4"
    assert_equal 4.01, payout.total_diff
    assert_empty Share.unpaid.accepted.to_a
  end
end
