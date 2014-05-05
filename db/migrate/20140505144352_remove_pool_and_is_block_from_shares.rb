class RemovePoolAndIsBlockFromShares < ActiveRecord::Migration
  def change
    remove_column :shares, :pool, :string
    remove_column :shares, :is_block, :boolean
  end
end
