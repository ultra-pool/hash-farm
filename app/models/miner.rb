class Miner < ActiveRecord::Base
  has_many :workers
  has_many :shares, through: :workers

  # Sum all user's workers' hashrate.
  # See Worker.hashrate for more information.
  def hashrate( *args, **hargs )
    workers.map { |w| w.hashrate( *args, **hargs ) }.sum
  end

  def balance
    Transfer.of(self).pluck(:amount).sum
  end

  def payable?
    balance > HashFarm.config.pool.min_payout
  end
end
