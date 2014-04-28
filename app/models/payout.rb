# -*- encoding : utf-8 -*-

require 'core_extensions'
require 'loggable'

# using CoreExtensions

class Payout < ActiveRecord::Base
  include Loggable

  # TODO: get them from config ?
  MINER_FEES = 0.005 # used in Payout.miner_fees_on
  MINER_MAX_FEES = 10**6 # Payout.miner_fees_on
  OUR_FEES = 0.02 # Payout.our_fees_on
  MINI_PAYOUT = 10**6 # BTC Satoshi

  @@mutex = Mutex.new

  # Je récupère
  def self.run
    @@mutex.synchronize do
      accounts = Account.where( coin_id: Coin.find_by(code: 'BTC'), label: ["pool", "rent", "blocks", "balances"] ).to_a
      shares = Share.unpaid.accepted.to_a
      payout = Payout.new( accounts, shares )
      payout.send_it!
      payout
    end
  end

  def Payout.miner_fees_on value
    fees = (value * MINER_FEES).floor
    fees = MINER_MAX_FEES if fees > MINER_MAX_FEES
    fees
  end

  def Payout.our_fees_on value
    (value * OUR_FEES).ceil
  end

  #####################################################################

  belongs_to :transaction
  alias_method :tx, :transaction
  has_many :shares

  # attr_accessible :tx
  # attr_accessible :miner_fees, :our_fees, :users_amount
  attr_reader :users_sum_crumbs, :miner_fees

  # Payout.new( accounts_ary, shares_ary )
  def initialize(*args, **kargs)
    objArg = OpenStruct.new(**kargs)
    @users_sum_crumbs = 0
    
    coin = objArg.delete(:coin) || Coin["BTC"]
    rpc = objArg.delete(:rpc) || coin.rpc

    # at least one Account in inputs, and outputs are all Shares.
    return super( *args, **objArg.to_h ) unless args.size == 2
    raise unless args.all? { |arg| arg.kind_of?(Array) }
    raise unless args[0].all? { |arg| arg.kind_of?( Account ) }
    raise unless args[1].all? { |arg| arg.kind_of?( Share ) }

    accounts, shares = *args.shift(2)

    super( *args, **objArg.to_h )

    self.transaction = Transaction.new( coin: coin, rpc: rpc )

    # Retrieve unspent transactions and add them to inputs
    init_inputs( accounts )
    # Compute what go to us, miner and users.
    @miner_fees, self.our_fees, self.users_amount = *compute_fees
    # 
    add_shares( shares )
  end

  def total_diff
    @total_diff ||= shares.map(&:difficulty).sum
  end

  def to_h
    {
      transaction: tx,
      miner_fees: miner_fees,
      our_fees: our_fees,
      users_amount: users_amount,
    }
  end

  def send_it!
    tx.send_it!
    log.info(
      "Payout sent for shares #{shares.first.id}..#{shares.last.id} :\n" +
      "- Our fees     : #{our_fees.to_f / 10**8} BTC ;\n" +
      "- Users amount : #{users_amount.to_f / 10**8} BTC ;"
    )
    self.save!
    shares.each do |s| s.update!(payout_id: self.id) end
  end

  private
    def init_inputs( accounts )
      accounts.each do |account|
        account.listunspent.each do |t|
          self.tx.add_input( t.txid, t.vout, t.amount )
        end
      end
    end

    def compute_fees
      total_amount = tx.total_input
      miner_fees = Payout.miner_fees_on( total_amount )
      our_fees = Payout.our_fees_on( total_amount )
      users_amount = total_amount - miner_fees - our_fees
      if total_amount != our_fees + users_amount + miner_fees
        raise "diff in total sum : #{total_amount} != #{our_fees} + #{users_amount} + #{miner_fees}" end
      [miner_fees, our_fees, users_amount]
    end

    # Array of Share
    def add_shares( shares )
      return if shares.empty?
      
      # Add new shares to previous ones.
      self.shares += shares

      # return a quadruple (user, diff, output, delta_balance)
      res = shares.group_by(&:user).map do |user, shares|
        diff = shares.map(&:difficulty).sum
        diff_sum = (users_amount * diff / total_diff).floor
        bal_sum = user.balance
        if diff_sum + bal_sum >= MINI_PAYOUT
          tx.add_output( user, diff_sum + bal_sum )
          user.balance = 0
        else
          user.update!( balance: user.balance + diff_sum )
        end
        [user, diff, tx.outputs[user.payout_address], user.balance - bal_sum]
      end

      users_diff_sum = res.inject(0) { |r, t| r += t[1] }
      raise "difference in difficulty sum : #{users_diff_sum} != #{total_diff}" if users_diff_sum.to_f != total_diff.to_f
      users_sum = res.inject(0) { |r, t| r += t[2] + t[3] }
      @users_sum_crumbs = users_amount - users_sum
      log.warn "Too many crumbs on users_amount : #{@users_sum_crumbs} for #{res.size} users" if @users_sum_crumbs > res.size
      raise "diff in user sum : #{users_sum} != #{users_sum + @users_sum_crumbs}" if users_amount != users_sum + @users_sum_crumbs

      # Add Fees
      self.users_amount -= @users_sum_crumbs
      self.our_fees += @users_sum_crumbs
      tx.add_output( Account.find_by(label: "fees"), self.our_fees )

      # Balance
      balances_in_sum = res.inject(0) { |r, t| t[3] > 0 ? r + t[3] : r }
      balances_out_sum = res.inject(0) { |r, t| t[3] > 0 ? r : (r - t[3]) }
      new_balance = res.map { |t| t[3] }.sum
      raise "difference in balance sum : #{new_balance} != #{balances_in_sum} - #{balances_out_sum}" if new_balance != balances_in_sum - balances_out_sum
      balances_account = Account.find_by(label: "balances")
      final_balance = balances_account.balance + balances_in_sum - balances_out_sum
      raise "final_balance too low : #{final_balance}" if final_balance < 0
      tx.add_output( balances_account, final_balance ) if final_balance != 0

      return {
        balance: {
          in: balances_in_sum,
          out: balances_in_sum
        },
        crumbs: @users_sum_crumbs,
        shares: res
      }
    end
end
