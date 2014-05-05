class DropPayoutsTable < ActiveRecord::Migration
  def change
    drop_table :payouts
  end
end
