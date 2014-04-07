# -*- encoding : utf-8 -*-

require 'core_extensions'
require "protocol/stratum"

# using CoreExtensions

# Signals :
# - pool_changed(old_pool, new_pool)
# - subscribed
class WorkerConnection < EM::Connection
  include Loggable
  include Listenable

  include Stratum::Handler

  SMALLEST_DIFFICULTY = 2**-16 # Mini CGMiner pool diff.
  NB_SHARE_MEAN = 10

  attr_accessor :worker

  #### READ-ONLY
  # Hash of String notification => String UUID
  attr_reader :subscriptions
  # Hash of job_id => aFloat
  attr_reader :jobs_pdiff
  # Hex String, same size as extra_nonce_2_size
  attr_accessor :extra_nonce_1
  # Integer, in bytes
  attr_reader :extra_nonce_2_size
  # TODO: move them in model
  # Array
  attr_reader :shares

  # Time
  attr_reader :created_at

  #### READ / WRITE
  # String
  attr_accessor :name
  # Worker
  attr_reader :model
  # Pool
  attr_reader :pool
  # Integer
  attr_reader :difficulty
  attr_accessor :next_difficulty
  # String
  attr_reader :type
  # Integer
  attr_accessor :stales

  def initialize
    super(nil)

    @created_at = Time.now

    @subscriptions = {}
    @jobs_pdiff = {}
    extra_nonce_2_size = 4
    @difficulty = @next_difficulty = SMALLEST_DIFFICULTY
    @stales = 0

    # TODO: move them in model
    @shares = []
  end

  def post_init
    super
    init_listeners
    update_name
  end

  def init_listeners
    # mining.on('subscribe') do |req| on_subscribe( req ) end # Called in MainServer
    mining.on('unsubscribe') do |req| on_unsubscribe( req ) end
    mining.on('submit') do |req| on_submit( req ) end
  end

  def reinit( worker )
    @subscriptions = worker.subscriptions
    @jobs_pdiff = worker.jobs_pdiff
    @extra_nonce_2_size = worker.extra_nonce_2_size
    @extra_nonce_1 = worker.extra_nonce_1
    @difficulty = worker.difficulty
    @next_difficulty = worker.next_difficulty
    @stales = worker.stales
    @shares = worker.shares
    @pool = worker.pool
    @type = worker.type
    @model = worker.model
    @name = worker.name
    @skip_jsonrpc_field = worker.skip_jsonrpc_field
    @response_waited = worker.response_waited
  end

  ##########################################################

  def extra_nonce_2_size=( size )
    return size if size == @extra_nonce_2_size
    @extra_nonce_2_size = size
    @extra_nonce_1 = rand( 256**size ).to_hex
    size
  end

  def pool=( new_pool )
    old_pool = @pool
    return if new_pool == old_pool
    client.reconnect() unless old_pool.nil?
    @pool = new_pool
    log.debug("[#{name}] change pool : #{old_pool.name} => #{new_pool.name}") unless old_pool.nil?
    emit( 'pool_changed' )
    new_pool.add_worker( self )
    new_pool
  rescue => err
    log.error "Error during pool= : #{err}\n" + err.backtrace[0..5].join("\n")
  end

  def type=( args )
    return if args.empty?
    puts("[#{name}] type found")
    if args.first =~ %r{^(\w+)/([\d\.]+)$}
      @type = [$1, $2]
      if @type[0].downcase == "cgminer" && @type[1] <= "3.7.2"
        log.warn "#{@type.join('/')} not supported ! MUST upgrade to 3.7.3 or use sgminer or cpuminer."
      end
    else
      log.warn "Unsupported type : #{args.inspect}"
    end
    log.warn "Unknow subscribe args : #{args.inspect}" if args.size > 1
    args
  end

  def model=( worker )
    log.debug("[#{name}] model found")
    @model = worker
    update_name
    worker
  end

  def add_share( share )
    shares << share
    shares.shift if shares.size > 50
    share
  end

  ##########################################################

  def set_difficulty diff=@next_difficulty
    log.debug("[#{name}] change diff #{@difficulty} => #{diff}")
    diff = SMALLEST_DIFFICULTY if diff < SMALLEST_DIFFICULTY
    @difficulty = @next_difficulty = diff
    mining.set_difficulty( diff )
  end

  def notify job
    set_difficulty( @next_difficulty ) if @next_difficulty != @difficulty
    return if ! @subscriptions["mining.notify"]
    jobs_pdiff[job.id] = @difficulty
    jobs_pdiff.shift if jobs_pdiff.size > 50
    log.debug "[#{name}] notified with job #{job.id}"
    mining.notify *job.to_stratum
  end

  ##########################################################

  def on_subscribe req
    log.debug("[#{name}] subscribe")
    type = req.params

    @subscriptions["mining.notify"] = rand( 256**8 ).to_hex if ! @subscriptions["mining.notify"]
    @subscriptions["mining.set_difficulty"] = rand( 256**8 ).to_hex if ! @subscriptions["mining.set_difficulty"]
    @extra_nonce_1, @extra_nonce_2_size, diff, job = *@pool.subscribe(self)

    req.respond [[subscriptions], @extra_nonce_1, @extra_nonce_2_size]
    log.verbose "[#{name}] subscribed : extra1=#{@extra_nonce_1}, extra2size=#{@extra_nonce_2_size}."
    emit( 'subscribed' )

    set_difficulty( diff )
    notify( job ) if job
  end

  def on_unsubscribe req
    log.verbose "[#{name}] unsubscribe."
    uuid = req.params.first
    res = @subscriptions.delete( @subscriptions.key( uuid ) ) == uuid
    req.respond res
  end

  def on_submit req
    log.debug("[#{name}] submit")
    @pool.submit( self, req )
  end

  ##########################################################

  def btc_address
    @model.user.btc_address rescue nil
  end

  def valid_shares
    shares.select(&:valid_share?)
  end

  def invalid_shares
    shares.reject(&:valid_share?)
  end

  # Compute worker's hashrate from his shares
  #
  # Avg nb hash to find a hash <= target_of_diff_D
  # = 2**256 / ( (0xffff * 2**208) / D ) )
  # = D * 2**256 / (0xffff * 2**208)
  # = D * 2**48 / 0xffff
  # =~ D * 2**32
  #
  # sum( shares.difficulties ) * 2**32 == nb hash done by worker
  # sum( shares.difficulties ) * 2**32 / time_to_do_them == hashrate
  #
  # => anInteger
  def hashrate
    if shares.empty?
      rate = 2000 # default, 2 khash
    elsif shares.size < NB_SHARE_MEAN
      sum_diff = shares.map(&:worker_difficulty).sum
      time = Time.now - created_at
      rate = (sum_diff / time * 2 ** 32).round
    else
      sum_diff = shares[-NB_SHARE_MEAN..-1].map(&:worker_difficulty).inject(:+)
      time = Time.now - shares[-NB_SHARE_MEAN].created_at
      rate = (sum_diff / time * 2 ** 32).round
    end
    log.verbose "[" + @name + "] hashrate is " + rate.to_s
    rate
  end

  def valid_hashrate
    vshares = valid_shares
    if vshares.empty?
      valid_rate = 0 # default, 0 khash
    elsif vshares.size < NB_SHARE_MEAN
      valid_rate = vshares.map(&:worker_difficulty).sum / (Time.now - created_at) * 2 ** 32
    else
      valid_rate = vshares[-NB_SHARE_MEAN..-1].map { |s| s.worker_difficulty }.inject(:+) / (Time.now - vshares[-NB_SHARE_MEAN].created_at) * 2 ** 32
    end
    valid_rate = valid_rate.round
    log.verbose "[" + @name + "] valid_hashrate is " + valid_rate.to_s
    valid_rate
  end

  def invalid_hashrate
    invshares = invalid_shares
    if invshares.empty?
      invalid_rate = 0 # default, 0 khash
    elsif invshares.size < NB_SHARE_MEAN
      sum_diff = invshares.map(&:worker_difficulty).sum
      time = Time.now - created_at
      invalid_rate = sum_diff / time * 2 ** 32
    else
      sum_diff = invshares[-NB_SHARE_MEAN..-1].map(&:worker_difficulty).inject(:+)
      time = Time.now - invshares[-NB_SHARE_MEAN].created_at
      invalid_rate = sum_diff / time * 2 ** 32
    end
    invalid_rate = invalid_rate.round
    log.verbose "[" + @name + "] invalid_hashrate is " + invalid_rate.to_s
    invalid_rate
  end

  def inspect
    "%s@%s<en1: '%s', en2size: %d, hrate: %d kHps, pool: %s>" % [@name, @ip_port, @extra_nonce_1, @extra_nonce_2_size, (hashrate / 1000 rescue -1), @pool && @pool.name]
  end

  def update_name
    if rip =~ /^192.168.0.(\d+)$/
      @name = "EPIC-#{$~[1]}"
      @name += "-" + btc_address[0..3] if btc_address.present?
    elsif @model && @model.name.present? && @model.user.name.present?
      @name = @model.fullname
    elsif @model && @model.user.name.present?
      @name = @model.user.name + "@" + rport
    elsif @model && @model.name.present?
      @name = @model.user.btc_address[0...8] + "@" + rport
    elsif @btc_address
      @name = @model.user.btc_address[0...8] + "@" + rport
    else
      @name = ip_port
    end
  end
end
