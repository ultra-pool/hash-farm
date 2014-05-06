class RemovePayoutAddressNotNullOption < ActiveRecord::Migration
  def change
  end
  def self.up
    change :user, :payout_address, :string, limit: 34
  end
  def self.down
    change :user, :payout_address, :string, limit: 34, null: false
  end
end
