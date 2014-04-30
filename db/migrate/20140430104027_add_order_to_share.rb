class AddOrderToShare < ActiveRecord::Migration
  def change
    add_reference :shares, :order, index: true
  end
end
