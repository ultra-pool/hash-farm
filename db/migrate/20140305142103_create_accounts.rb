class CreateAccounts < ActiveRecord::Migration
  def change
    create_table :accounts do |t|
      t.references :coin, index: true, null: false
      t.string :address, limit: 34, null: false
      t.string :label, limit: 255, null: false

      t.timestamps
    end
  end
end
