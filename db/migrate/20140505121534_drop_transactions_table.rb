class DropTransactionsTable < ActiveRecord::Migration
  def change
    drop_table :transactions
  end
end
