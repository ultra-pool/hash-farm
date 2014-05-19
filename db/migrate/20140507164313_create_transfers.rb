class CreateTransfers < ActiveRecord::Migration
  def change
    create_table :transfers do |t|
      t.decimal :amount, null: false, precision: 16, scale: 8
      t.references :sender, index: true
      t.references :recipient, index: true
      t.string :txid, length: 64
      t.integer :vout

      t.timestamps
    end

    add_reference :shares, :transfer, index: true
  end
end
