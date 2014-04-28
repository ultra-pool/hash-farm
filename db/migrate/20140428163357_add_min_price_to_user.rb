class AddMinPriceToUser < ActiveRecord::Migration
  def change
    add_column :users, :min_price, :decimal, precision: 16, scale: 8, null: false
  end
end
