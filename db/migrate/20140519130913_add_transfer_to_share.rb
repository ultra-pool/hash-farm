class AddTransferToShare < ActiveRecord::Migration
  def change
    add_reference :shares, :transfer, index: true
  end
end
