class CreateMiners < ActiveRecord::Migration
  def change
    create_table :miners do |t|
      t.string :address, length: 34, null: false

      t.timestamps
    end
  end
end
