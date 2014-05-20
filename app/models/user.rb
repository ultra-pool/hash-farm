class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :confirmable

  has_many :transfers
  has_many :orders

  # BEFORE VALIDATION

  before_validation :set_is_admin, if: -> { self.is_admin.nil? }

  def set_is_admin
    self.is_admin = false
    true
  end

  # VALIDATION

  validates :is_admin, :email, :password, presence: true
  validates :password, length: { minimum: 6 }
  validate :password_has_at_least_a_min_a_maj_a_digit_and_a_special_char

  def password_has_at_least_a_min_a_maj_and_a_special_char
    errors.add(:password, "Must contains a minuscule") unless password =~ /[a-z]/
    errors.add(:password, "Must contains a majuscule") unless password =~ /[A-Z]/
    errors.add(:password, "Must contains a digit") unless password =~ /[0-9]/
    errors.add(:password, "Must contains a special char") unless password =~ /\W/
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
    vout = btc_tx.outs.find_index { |txout| txout.address == wallet_address }
    amount = btc_tx.outs[vout].amount
    Transfer.create!( user: self, amount: amount, txid: btc_tx.id, vout: vout )
  end

  def withdraw( address, amount=nil )
    raise "assert amount <= user.balance failed" if amount.present? && amount > balance
    amount ||= balance
    raise "nothing to withdraw" if amount == 0
    # btc_tx = Something.create_btc_tx( address => amount )
    vout = btc_tx.outs.find_index { |txout| txout.address == address }
    Transfer.create!( user: self, amount: -amount, txid: btc_tx.id, vout: vout )
    btc_tx
  end
end
