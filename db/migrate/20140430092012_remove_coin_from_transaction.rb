class RemoveCoinFromTransaction < ActiveRecord::Migration
  def change
    remove_column :transactions, :coin_id
  end
end
