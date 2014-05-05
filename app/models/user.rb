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

end
