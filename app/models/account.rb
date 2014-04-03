class Account < ActiveRecord::Base
  belongs_to :coin
  has_many :payouts, through: :accounts_payouts

  scope :mining, -> { where(label: "mining") }

  def balance
    miniconf = self.label == "mining" ? coin.block_confirmation : coin.transaction_confirmation
    (coin.rpc.getbalance( self.label, miniconf ) * 10**8).to_i
  end

  def immature_balance
    coin.rpc.getbalance( self.label, 0 ) - balance
  end

  # Return an Array of Hash with :
  # - txid,
  # - vout,
  # - amount in Satoshi,
  # - transaction objects :
  # {
  #     "txid" : "fc9f5129bd45b728192fa7c5c753ef0f11e0a29d880f057c524b40878fb46c3f",
  #     "version" : 1,
  #     "locktime" : 0,
  #     "vin" : [
  #         {
  #             "coinbase" : "0393550d062f503253482f040e541453081fffffff000000000d2f6e6f64655374726174756d2f",
  #             "sequence" : 0
  #         }
  #     ],
  #     "vout" : [
  #         {
  #             "value" : 50.00000000,
  #             "n" : 0,
  #             "scriptPubKey" : {
  #                 "asm" : "OP_DUP OP_HASH160 68774ccce28e268ff0d350d8c4978c48c2e06c24 OP_EQUALVERIFY OP_CHECKSIG",
  #                 "hex" : "76a91468774ccce28e268ff0d350d8c4978c48c2e06c2488ac",
  #                 "reqSigs" : 1,
  #                 "type" : "pubkeyhash",
  #                 "addresses" : [
  #                     "eBcrn3taUXYj6itsjfz6hrFk1PJQ2c3b9g"
  #                 ]
  #             }
  #         }
  #     ]
  # }
  def listunspent( miniconf=coin.transaction_confirmation )
    coin.rpc.listunspent( miniconf, self.label ).map do |tx|
      tx["amount"] = (tx["amount"] * 10**8).to_i
      OpenStruct.new( tx )
    end
  end

  # Add "to_hash" field with full raw decoded tx.
  def listunspent2( miniconf=coin.transaction_confirmation )
    listunspent( miniconf ).map { |tx|
      hex = coin.rpc.getrawtransaction( tx.txid )
      tx.to_hash = coin.rpc.decoderawtransaction( hex )
    }
  end

  # Add "to_tx" field with Bitcoin::Protocol::Tx object.
  def listunspent3( miniconf=coin.transaction_confirmation )
    listunspent( miniconf ).map { |tx|
      hex = coin.rpc.getrawtransaction( tx.txid )
      tx.to_tx = Bitcoin::Protocol::Tx.new( [hex].pack("H*") )
    }
  end
  # # Return an Array of Bitcoin::Protocol::Tx.
  # def listunspent2
  #   rpc = coin.rpc
  #   rpc.listunspent( coin.transaction_confirmation, self.address ).map { |tx|
  #     hex = rpc.getrawtransaction( tx["txid"] )
  #     tx = Bitcoin::Protocol::Tx.new([hex].pack("H*"))
  #     vout = tx.out.index { |out| out["scriptPubKey"]["addresses"].first == self.address }
  #     amount = tx.out[vout]["value"] * 10**8
  #     {tx: tx, txid: tx["txid"], vout: vout, amount: amount}
  #   }
  # end
end
