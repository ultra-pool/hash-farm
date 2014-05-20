require 'test_helper'

class UserTest < ActiveSupport::TestCase

  test "it should know the user deposit bitcoin address from a public seed" do
    u = users(:mv)

    HashFarm.config.serialized_master_key = {
      private: nil,
      public: 'xpub661MyMwAqRbcG2V5zGfVX28LzHCBm7BHhEeMun3WjJUJQhmT6SnhpF2m2BXh7bwnbQ3x3oRGW2hjxzkBcCu8oDjNod4cUJT9j5pHoMVFGsE'
    }
    assert_equal('1EmVWFtXja1MM6u6pLjWU2wm9dStXyPXZ9', u.deposit_key.addr)
    assert_equal(nil, u.deposit_key.priv)
  end

  test "it should know the user deposit bitcoin address from a private seed" do
    u = users(:mv)
    HashFarm.config.serialized_master_key = {
      private: 'xprv9s21ZrQH143K3YQctF8V9tBcSFMhMeTSL1im7PduAxwKXuSJYuUTGSiHAuY1r7PTPBkx4M7uMjHJaogx24szcMRVUD3xojm1fN1YqR51FvP',
      public: nil
    }
    assert_equal('1EmVWFtXja1MM6u6pLjWU2wm9dStXyPXZ9', u.deposit_key.addr)
    assert_equal('f4202564a4b5d6d8dcd0eb8ce7bc889ac156ac87822c833779a3be1bee1c1baa', u.deposit_key.priv)
  end

  test "it should compute balances" do
    assert_equal 0.01, users(:buyer).balance
    assert_equal 0, users(:barbu).balance
    assert_equal 0, users(:toto).balance
    assert_equal 0.5, users(:one).balance
  end

  test "it should create transfer when received_credit" do
    barbu = users(:barbu)
    txid = "d1e21e283d5e917b2ddd01c0a579d41d4b0e60062890f1958485ea86b3f24743"
    btc_tx = OpenStruct.new(
      id: txid,
      outs: [OpenStruct.new( address: barbu.wallet_address, amount: 1.5 )]
    )
    old_balance = barbu.balance
    barbu.received_credit( btc_tx )
    assert_equal old_balance + 1.5, barbu.balance
    tf = barbu.transfers.credits.last
    assert_equal barbu, tf.user
    assert_equal txid, tf.txid
    assert_equal 0, tf.vout
    assert_equal 1.5, tf.amount
  end

  test "it should create transfer on withdraw" do
    barbu = users(:barbu)

    create_btc_mock = -> (tx) {
      txid = "d1e21e283d5e917b2ddd01c0a579d41d4b0e60062890f1958485ea86b3f24743"
      btc_tx = OpenStruct.new(
        id: txid,
        outs: tx
      )
    }

    old_balance = barbu.balance
    skip("Create BTC Tx not implemented yet")
    btc_tx = barbu.withdraw
    tf = barbu.transfers.withdraws.last

    assert_equal 0, barbu.balance
    assert_equal barbu, tf.user
    assert_equal txid, tf.txid
    assert_equal 0, tf.vout
    assert_equal old_balance, tf.amount
  end
end
