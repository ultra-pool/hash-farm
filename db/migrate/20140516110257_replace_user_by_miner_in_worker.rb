class ReplaceUserByMinerInWorker < ActiveRecord::Migration
  def change
    remove_column :workers, :user_id
    add_column :workers, :miner_id, :integer, references: :miners
  end
end
