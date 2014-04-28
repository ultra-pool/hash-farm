class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.references :user, index: true, null: false

      t.string :algo, limit: 32, default: 'scrypt', null: false
      t.string :url, limit: 255, null: false
      t.string :username, limit: 255, null: false
      t.string :password, limit: 255, null: false

      t.decimal :pay, null: false, precision: 16, scale: 8
      t.decimal :price, null: false, precision: 16, scale: 8
      t.integer :limit

      t.integer :hash_done, null: false, default: 0, limit: 64.bytes
      t.boolean :complete, null: false, default: false
      t.boolean :running, null: false, default: false

      t.timestamps
    end
  end
end
