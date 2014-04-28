class User < ActiveRecord::Base
  has_many :workers
  has_many :shares, through: :workers
  
  before_validation :set_is_anonymous, if: -> { self.is_anonymous.nil? }
  before_validation :set_is_admin, if: -> { self.is_admin.nil? }

  def set_is_anonymous
    self.is_anonymous = name.blank? || password.blank?
    true
  end

  def set_is_admin
    self.is_admin = false
    true
  end

  def name
    super || self.payout_address
  end
end
