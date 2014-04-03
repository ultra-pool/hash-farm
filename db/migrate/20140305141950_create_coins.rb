class CreateCoins < ActiveRecord::Migration
  def change
    create_table :coins do |t|
      t.string :name, limit: 64, null: false, unique: true
      t.string :code, limit: 5, null: false, unique: true
      t.integer :second_per_block, null: false
      t.integer :difficulty_retarget, null: false
      t.string :algo, limit: 64, null: false
      t.integer :block_confirmation, null: false
      t.integer :transaction_confirmation, null: false
      t.string :rpc_url, limit: 255, null: false, unique: true
      t.string :bitcointalk_url, limit: 255
      t.string :website, limit: 255

      t.timestamps
    end
  end
end
