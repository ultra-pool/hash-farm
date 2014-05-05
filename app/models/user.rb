class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :confirmable

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

  # Sum all user's workers' hashrate.
  # See Worker.hashrate for more information.
  def hashrate( *args, **hargs )
    workers.map { |w| w.hashrate( *args, **hargs ) }.sum
  end
end
