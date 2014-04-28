class AddWalletAddressToUser < ActiveRecord::Migration
  def change
    add_column :users, :wallet_address, :string, limit: 34
    rename_column :users, :btc_address, :payout_address
  end
end
