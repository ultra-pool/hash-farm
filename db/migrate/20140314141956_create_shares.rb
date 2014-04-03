class CreateShares < ActiveRecord::Migration
  def change
    create_table :shares do |t|
      t.references :worker, null: false
      t.string :pool, limit: 64, null: false
      t.string :solution, null: false, limit: 64
      t.float :difficulty, null: false
      t.boolean :our_result, null: false
      t.boolean :pool_result
      t.string :reason, limit: 255
      t.boolean :is_block, null: false
      t.references :payout, index: true

      t.timestamps
    end
  end
end
