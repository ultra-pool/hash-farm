class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name, limit: 64
      t.string :password, limit: 64
      t.string :email, limit: 255
      t.string :btc_address, null: false, limit: 34
      t.boolean :is_anonymous, null: false
      t.boolean :is_admin, null: false
      t.integer :balance, default: 0

      t.timestamps
    end
  end
end
