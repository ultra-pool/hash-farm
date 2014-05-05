class RemovePayoutFromShares < ActiveRecord::Migration
  def change
    remove_reference :shares, :payout, index: true
  end
end
