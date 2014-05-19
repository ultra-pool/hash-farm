class RenameSenderAndRecipientFromTransfer < ActiveRecord::Migration
  def change
    change_table :transfers do |t|
      t.rename :sender_id, :user_id
      t.references :miner, index: true
      t.references :order, index: true
    end
    remove_reference :transfers, :recipient, index: true
  end
end
