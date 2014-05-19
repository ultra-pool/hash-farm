# -*- encoding : utf-8 -*-

class Order < ActiveRecord::Base
  include Comparable

  PRICE_MIN = 0.001 # Too small for the moment, will never be proccessed.
  PRICE_MAX = 0.05 # To prevent user error
  PAY_MIN = 0.0002 # ~ 1 MHs for an hour.
  PAY_MAX = 10 # To prevent user error

  belongs_to :user
  has_many :shares
  has_many :transfers

  # Strings :
  # attr_accessible :algo, :url, :username, :password
  # Numbers :
  # - pay is in BTC
  # - price is in BTC / MHs / Day
  # - limit is in MHs. nil stand for no limit == Float::INFINITY
  # attr_accessible :pay, :price, :limit, :hash_done
  # Booleans :
  # attr_accessible :running, :complete
  
  before_validation do
    uri = URI(self.url) rescue nil
    next false if uri.nil?
    if self.username.blank?
      self.username = uri.user
      self.password = uri.password if self.password.blank?
      uri.password = uri.user = nil
      self.url = uri.to_s
    end
    self.username && uri.host =~ /^[\w\.-]+$/
  end

  validates :url, :username, :pay, :price, presence: true
  validate :url_is_well_formed
  def url_is_well_formed
    URI( self.url ).host.present? rescue false
  end
  validates :pay, numericality: { greater_than_or_equal_to: PAY_MIN }
  validates :pay, numericality: { less_than_or_equal_to: PAY_MAX }
  validates :price, numericality: { greater_than_or_equal_to: PRICE_MIN }
  validates :price, numericality: { less_than_or_equal_to: PRICE_MAX }

  scope :waiting, -> { where( running: false ) }
  scope :running, -> { where( running: true ) }
  scope :alive, -> { uncomplete }
  scope :complete, -> { where( complete: true ) }
  scope :uncomplete, -> { where( complete: false ) }

  # Debit user, initialize and return a new order.
  def Order.factory( args={} )
    user, amount, price, limit = args[:user], args[:pay], args[:price], args[:limit]
    raise "Not enough money in user balance." if user.balance < amount
    raise "amount is not in acceptable range" if ! amount.between?( PRICE_MIN, PRICE_MAX )
    raise "price is not in acceptable range" if ! price.between?( PAY_MIN, PAY_MAX )
    raise "limit is not in acceptable range" if limit.present? && ! limit > 1

    order = Order.create!( **args )
    transfer = Transfer.create!( user: user, amount: -amount, order: order )
    order
  end

  def cancel
    self.set_complete
    if Pool[pool_name]
      # Stop pool
      self.pool.on('stopped') do
        # paid shares
        self.pay!
        # recrédite du order.amount qu'il reste après les payouts.
        Transfer.create!( order: self, user: user, amount: self.pay )
      end
      self.pool.stop
    else
      self.pay!
      Transfer.create!( order: self, user: user, amount: self.pay )
    end
  end

  def uri() @uri = URI( self.url ); @uri.user = self.username; @uri.password = self.password; @uri end
  def host() uri.host end
  def port() uri.port end
  def hash_to_do() (self.pay / self.price * 10**6 * 1.day).round - self.hash_done end
  def pool_name() "order##{self.id}@#{host}" end

  after_initialize do |order|
    self.created_at ||= Time.now
    self.hash_done ||= 0
  end

  def limited?
    ! self.limit.nil?
  end

  def pool
    Pool[pool_name] || RentPool.new( self )
  end

  def <=>( o )
    r = self.price <=> o.price
    r = o.created_at <=> self.created_at if r == 0
    r
  end

  def complete?
    self.complete || self.hash_done > hash_to_do
  rescue => err
    p [self.complete, self.hash_done, hash_to_do]
    puts "#{err}\n" + err.backtrace.join("\n")
    false
  end
  alias_method :done?, :complete?

  def set_complete
    update!( complete: true )
  end
  def set_waiting( bool=false )
    update!( running: bool )
  end
  def set_running( bool=true )
    update!( running: bool )
  end

  # # Get payable shares for this order, group them by user,
  # # and create a Tranfer to pay him.
  # # Get a pool fee for each transfer.
  # def pay_miners!
  #   pool_fees = HashFarm.config.pool.fees_percent

  #   # Compute how much we must pay.
  #   to_pay_shares = shares.payable
  #   total_diff = shares.map(&:difficulty).sum
  #   total_nb_hash = MiningHelper.difficulty_to_nb_hash( total_diff )
  #   to_pay = (total_nb_hash.to_f * price / 10**2 / 1.day).round.btc # * 10**8 / 10**6
  #   to_pay = self.pay.btc - self.paid.btc if to_pay + self.paid.btc > self.pay.btc
  #   raise "Fail on assert to_pay <= order.user.balance" if to_pay > self.user.balance.btc

  #   # Create a Transfer per user, 
  #   tfs = to_pay_shares.group_by(&:user).map { |miner, user_shares|
  #     # Compute user part of to_pay
  #     user_total_diff = user_shares.map(&:difficulty).sum
  #     user_part = ( to_pay * user_total_diff.to_f / total_diff ).floor
  #     # 
  #     user_percentage = 1 - ( pool_fees < 0.1 ? pool_fees : pool_fees / 100.0 )
  #     #
  #     user_amount = (user_part * user_percentage).floor
  #     tf = Transfer.create!( sender: self.user, recipient: miner, amount: user_amount.to_btc )
  #     user_shares.each { |s| s.transfer = tf; s.save! }
  #     tf
  #   }

  #   # Compute our pool fees
  #   fees_user = User.find_or_create_by!( payout_address: HashFarm.config.pool.fees_address )
  #   fees_amount = to_pay - tfs.map(&:amount).sum.btc
  #   pool_fees_tf = Transfer.create!( sender: self.user, recipient: fees_user, amount: fees_amount.to_btc )
  #   raise "Fail on assert tfs.sum + pool.fees == to_pay" if tfs.map(&:amount).sum.btc + pool_fees_tf.amount.btc != to_pay

  #   self.paid += to_pay.to_btc
  #   raise "Fail on assert self.paid <= self.pay" if self.paid > self.pay

  #   self.complete = true if self.paid == self.pay
  #   save!
  # end

  # # Pay all alive order.
  # def Order.pay_miners!
  #   Order.alive.each(&:pay!)
  # end
end
