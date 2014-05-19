class RemovePayoutAddressNotNullOption < ActiveRecord::Migration
  def up
    change_column_null(:users, :payout_address, true)
  end
  def down
    change_column_null(:users, :payout_address, false)
  end
end
