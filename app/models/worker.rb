class Worker < ActiveRecord::Base
  belongs_to :user
  has_many :shares

  before_validation :set_is_anonymous, if: -> { self.is_anonymous.nil? }

  def fullname
    (user.name || user.payout_address) + "." + (self.name || "anonymous")
  end

  def set_is_anonymous
    self.is_anonymous = self.name.blank?
    true
  end
end
