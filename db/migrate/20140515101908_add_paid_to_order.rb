class AddPaidToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :paid, :decimal, precision: 16, scale: 8, default: 0, null: false
  end
end
