# -*- encoding : utf-8 -*-

class Transfer < ActiveRecord::Base
  belongs_to :sender, :class_name => "User"
  belongs_to :recipient, :class_name => "User"

  # VALIDATION

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 10**-8, less_than: 21 * 10**6 }
  validates :txid, length: { is: 64 }, format: { with: /\A[a-fA-F0-9]+\z/ }, allow_nil: true
  validate :assert_2_and_only_2_of_sender_recipient_and_txid_are_present,
    :assert_vout_present_if_and_only_if_txid_is_present
  validates :vout, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def assert_2_and_only_2_of_sender_recipient_and_txid_are_present
    if sender_id.present?
      errors[:base] << "sender is present, wait one and only one of recipient and txid to be present" unless recipient_id.present? ^ txid.present?
    else
      errors[:base] << "sender is not present, wait recipient and txid to be present" unless recipient_id.present? && txid.present?
    end
  end

  def assert_vout_present_if_and_only_if_txid_is_present
    errors.add(:vout, "vout must be present with and only with txid") if vout.present? != txid.present?
  end

  # SCOPES

  scope :from, -> (user) { where( sender: user ) }
  scope :to, -> (user) { where( recipient: user ) }
  scope :of,  -> (user) { where( "sender_id = ? OR recipient_id = ?", user, user ) }

  def self.balance( user )
    to( user ).pluck(:amount).sum - from( user ).pluck(:amount).sum
  end

  def self.payouts( user )
    from( user ).where( recipient_id: nil )
  end
  def self.withdraws( user )
    self.payouts( user )
  end

  def self.credits( user )
    to( user ).where( sender_id: nil )
  end
end
