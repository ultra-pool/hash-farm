class CreateTransactions < ActiveRecord::Migration
  def change
    create_table :transactions do |t|
      t.references :coin, index: true
      t.string :raw
      t.string :txid
      t.string :ourid
      t.string :block

      t.timestamps
    end
  end
end
