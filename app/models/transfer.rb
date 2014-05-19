# -*- encoding : utf-8 -*-

class Transfer < ActiveRecord::Base
  belongs_to :user
  belongs_to :miner
  belongs_to :order

  # VALIDATION

  validates :amount, presence: true
  validates :txid, length: { is: 64 }, format: { with: /\A[a-fA-F0-9]+\z/ }, allow_nil: true
  validate :assert_2_and_only_2_of_user_miner_and_txid_are_present,
    :assert_vout_present_if_and_only_if_txid_is_present,
    :assert_txid_or_order_is_present,
    :assert_amount_has_not_satoshi_decimal

  validates :vout, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def assert_2_and_only_2_of_user_miner_and_txid_are_present
    if user_id.present?
      errors[:base] << "user is present, wait one and only one of miner and txid to be present" unless miner_id.present? ^ txid.present?
    else
      errors[:base] << "user is not present, wait miner and txid to be present" unless miner_id.present? && txid.present?
    end
  end

  def assert_vout_present_if_and_only_if_txid_is_present
    errors.add(:vout, "vout must be present with and only with txid") if vout.present? != txid.present?
  end

  def assert_txid_or_order_is_present
    errors.add(:base, "one and only one of txid and order must be present") unless order_id.present? ^ txid.present?
  end

  def assert_amount_has_not_satoshi_decimal
    if amount.blank? || amount == 0
      errors.add(:amount, "amount is blank")
    elsif amount - amount.floor(8) > 0
      errors.add(:amount, "amount has satoshi decimal")
    end
  end

  # SCOPES
  scope :credits, -> { where( 'miner_id IS NULL AND txid IS NOT NULL AND amount > 0' ) }
  scope :order_creations, -> { where( 'miner_id IS NULL AND txid IS NULL AND amount < 0' ) }
  scope :mini_payouts, -> { where( 'user_id IS NOT NULL AND miner_id IS NOT NULL' ) }
  scope :payouts, -> { where( 'user_id IS NULL' ) }
  scope :order_cancels, -> { where( 'miner_id IS NULL AND txid IS NULL AND amount > 0' ) }
  scope :withdraws, -> { where( 'miner_id IS NULL AND txid IS NOT NULL AND amount < 0' ) }

  scope :from, -> (user) { where( user: user ) }
  scope :to, -> (miner) { where( miner: miner ) }
end
