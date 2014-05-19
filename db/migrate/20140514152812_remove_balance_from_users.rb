class RemoveBalanceFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :balance, :integer
  end
end
