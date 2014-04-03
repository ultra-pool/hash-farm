class CreatePayouts < ActiveRecord::Migration
  def change
    create_table :payouts do |t|
      t.references :transaction, index: true, null: false
      t.integer :our_fees, null: false
      t.integer :users_amount, null: false

      t.timestamps
    end
  end
end
