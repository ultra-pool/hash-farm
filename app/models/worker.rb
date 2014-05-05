class Worker < ActiveRecord::Base
  belongs_to :user
  has_many :shares

  before_validation :set_is_anonymous, if: -> { self.is_anonymous.nil? }

  def fullname
    (user.name || user.payout_address) + "." + (self.name || "anonymous")
  end

  def set_is_anonymous
    self.is_anonymous = self.name.blank?
    true
  end

  # worker.hashrate() => aFloat
  # worker.hashrate(10.minutes) => aFloat
  # worker.hashrate(since: 10.minutes) => aFloat
  #
  # worker.hashrate(30.minutes, 20.minutes) => aFloat
  # worker.hashrate(since: 30.minutes, until: 20.minutes) => aFloat
  #
  # worker.hashrate(1.hour, slice: 10.minutes) => ary
  # worker.hashrate(since: 1.hour, slice: 10.minutes) => ary
  # worker.hashrate(1.hour, 30.minutes, slice: 10.minutes) => ary
  # worker.hashrate(since: 1.hour, until: 30.minutes, slice: 10.minutes) => ary
  #
  # To select only valid/invalid hashrate
  # worker.hashrate(validity: true/false) => aFloat
  # worker.hashrate(since: 1.hour, until: 30.minutes, slice: 10.minutes, validity: true/false) => ary
  #
  # May return nil if there is not enough shares in a slice.
  def hashrate( *args, **hargs )
    since = args[0] || hargs[:since] || 10.minutes.ago
    untl = args[1] || hargs[:until] || Time.now

    shrs = shares.where(created_at: since..untl)
    # shrs = shrs.where(our_result: hargs[:validity]) if hargs[:validity].present?

    if hargs[:slice]
      shrs_chunks = shrs.chunk { |s|
        ( (s.created_at - shrs.first.created_at) / hargs[:slice] ).floor
      }
      shrs_chunks.map(&:last).map do |ary|
        MiningHelper.hashrate( ary, hargs[:validity] )# rescue nil
      end
    else
      MiningHelper.hashrate( shrs, hargs[:validity] ) rescue nil
    end
  end

end
