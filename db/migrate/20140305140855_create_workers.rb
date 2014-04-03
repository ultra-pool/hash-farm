class CreateWorkers < ActiveRecord::Migration
  def change
    create_table :workers do |t|
      t.references :user, index: true, null: false
      t.string :name, limit: 63
      t.boolean :is_anonymous, null: false

      t.timestamps
    end
  end
end
