class DeleteMinerFieldsInUser < ActiveRecord::Migration
  def change
    remove_column :users, :name, :string, limit: 64
    remove_column :users, :payout_address, :string, limit: 34
    remove_column :users, :min_price, :decimal, precision: 16, scale: 8, default: 0.001, null: false
    remove_column :users, :is_anonymous, :boolean, null: false, default: true
    remove_column :workers, :is_anonymous, :boolean, null: false, default: true
    add_column :workers, :min_price, :decimal, precision: 16, scale: 8, default: 0.001, null: false
  end
end
