class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :confirmable

  # BEFORE VALIDATION

  before_validation :set_is_admin, if: -> { self.is_admin.nil? }

  def set_is_admin
    self.is_admin = false
    true
  end

  # INSTANCE METHODS

  def deposit_key
    if HashFarm.config.serialized_master_key[:private].nil?
      m = MoneyTree::Master.from_serialized_address HashFarm.config.serialized_master_key[:public]
      public_key = m.node_for_path("m/#{self.id}/0").public_key
      key = Bitcoin::Key.new(nil,public_key.to_hex, true)
    else
      m = MoneyTree::Master.from_serialized_address HashFarm.config.serialized_master_key[:private]
      private_key = m.node_for_path("m/#{self.id}/0").private_key
      key = Bitcoin::Key.new(private_key.to_hex, nil, true)
    end
    key
  end

  def balance
    Transfer.of(self).pluck(:amount).sum
  end

  def received_credit( btc_tx )
    vout = btc_tx.outs.index(user.wallet_address)
    amount = btc_tx.outs[vout]
    Transfer.create!( user: self, amount: amount, txid: btc_tx.id, vout: vout )
  end

  # def withdraw( address, amount=nil )
  #   raise "assert amount <= user.balance failed" if amount.present? && amount > balance
  #   amount ||= balance
  #   btc_tx = Something.create_btc_tx( address => amount )
  #   Transfer.create!( user: self, amount: -amount, txid: btc_tx.id, vout: btc_tx.outs.index(address) )
  #   btc_tx
  # end
end
