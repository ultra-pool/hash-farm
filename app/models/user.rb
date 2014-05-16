class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :confirmable
  
  before_validation :set_is_admin, if: -> { self.is_admin.nil? }

  def set_is_admin
    self.is_admin = false
    true
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
