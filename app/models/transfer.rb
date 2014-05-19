# -*- encoding : utf-8 -*-

# Fields are user_id, order_id, miner_id, amount, txid, vout.
#
# There is different kind of Transfer :
# - User credits
# - Order creations
# - Miners mini payouts
# - Miners payouts
# - Order cancellations
# - User Withdraws
#
# User credits
# -------
#
# Credits are BTC send by users to there account, in the aim to create orders.
# Members are user_id, amount, txid and vout (amount > 0).
#
# Order creations
# -------
#
# Order creations are BTC debited from the user account to finance orders.
# Members are user_id, order_id and amount (amount < 0).
#
# Miners mini payouts
# -------
#
# Miners mini payouts are BTC move from order to miners to pay shares.
# Members are order_id, miner_id and amount (amount > 0).
#
# Payouts
# -------
#
# Miners payouts are BTC credited to miners that are send with a real transaction.
# Members are miner_id, amount, txid and vout (amount < 0).
#
# Order cancellations
# -------
#
# Order cancellations are BTC send back to user when he cancel an order.
# Members are order_id, user_id and amount (amount > 0).
#
# User withdraws
# -------
#
# User withdraws are BTC that are send back to the user with a real transaction.
# Members are user_id, amount, txid and vout (amount < 0).
#
class Transfer < ActiveRecord::Base
  belongs_to :user
  belongs_to :miner
  belongs_to :order

  # VALIDATION

  validates :amount, presence: true
  validate :assert_user_or_miner_is_present,
    :assert_txid_or_order_is_present,
    :assert_vout_present_if_and_only_if_txid_is_present,
    :assert_amount_has_not_satoshi_decimal
  validates :txid, length: { is: 64 }, format: { with: /\A[a-fA-F0-9]+\z/ }, allow_nil: true
  validates :vout, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def assert_user_or_miner_is_present
    errors.add(:base, "one and only one of user_id and miner_id must be present") unless user_id.present? ^ miner_id.present?
  end

  def assert_txid_or_order_is_present
    errors.add(:base, "one and only one of txid and order must be present") unless order_id.present? ^ txid.present?
  end

  def assert_vout_present_if_and_only_if_txid_is_present
    errors.add(:vout, "vout must be present with and only with txid") if vout.present? != txid.present?
  end

  def assert_amount_has_not_satoshi_decimal
    if amount.blank? || amount == 0
      errors.add(:amount, "amount is blank")
    elsif amount - amount.floor(8) > 0
      errors.add(:amount, "amount has satoshi decimal")
    end
  end

  # SCOPES
  scope :credits, -> { where( 'user_id IS NOT NULL AND txid IS NOT NULL AND amount > 0' ) }
  scope :order_creations, -> { where( 'user_id IS NOT NULL AND order_id IS NOT NULL AND amount < 0' ) }
  scope :mini_payouts, -> { where( 'miner_id IS NOT NULL AND order_id IS NOT NULL' ) }
  scope :payouts, -> { where( 'miner_id IS NOT NULL AND txid IS NOT NULL' ) }
  scope :order_cancels, -> { where( 'user_id IS NOT NULL AND order_id IS NOT NULL AND amount > 0' ) }
  scope :withdraws, -> { where( 'user_id IS NOT NULL AND txid IS NOT NULL AND amount < 0' ) }

  # obj can be a User, Miner or Order
  scope :of, -> (obj) { where( obj.class.name.underscore.to_sym => obj ) }
end
