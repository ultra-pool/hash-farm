# -*- encoding : utf-8 -*-

require 'loggable'
require 'listenable'
require 'core_extensions'

require 'protocol/stratum/submit'

# using CoreExtensions

# La pool à un ensemble de connection @worker_connections
class Pool
  include Loggable
  include Listenable

  @@pools = {}

  def []( name ) @@pools[name] end

  DESIRED_GLOBAL_SHARE_RATE = 0.2 # 2 share per second

  attr_accessor :name
  attr_reader :workers
  attr_reader :desired_share_rate_per_worker
  attr_accessor :profitability_validity

  def initialize(name="", options={})
    @name, @options = name, options

    @workers = []
    @desired_share_rate_per_worker = DESIRED_GLOBAL_SHARE_RATE

    # Jobs managment
    @last_job
    @previous_jobs = {}

    # Shares managment
    @accepted_shares = 0
    @rejected_shares = 0

    # Pool's profitability
    @profitability_validity = 3600 # 1 hour
    @profitability_timeout = Time.now.to_f
  end

  def add_worker worker
    return if @workers.last == worker
    @workers << worker
    worker.pool = self
    worker.on( 'disconnect' ) do on_worker_pool_changed( worker ) end
    worker.on( 'pool_changed' ) do on_worker_pool_changed( worker ) end
    update_desired_share_rate_per_worker
    Pool.log.info "#{name} new worker #{worker.name} added. Now #{@workers.size} workers."
    emit( 'new_worker', worker )
  rescue => err
    log.error "Error during add_worker : #{err}\n" + err.backtrace[0..5].join("\n")
  end

  def subscribe worker
    extra2size = 4
    extra1 = rand( 256**extra2size ).to_hex(extra2size)
    diff = 2**-10
    # diff = 2**-16
    [extra1, extra2size, diff, @last_job]
  end

  def submit worker, req
    submit = Stratum::Submit.new(*req.params)

    Pool.log.debug("[#{name}][#{worker.name}] submit #{submit.to_a}")

    # Check job_id
    job = @previous_jobs[ submit.job_id ]
    # TODO: Allow share if it is just a second late
    if job.nil? && @previous_jobs.size == 0
      return req.respond( false ) && nil
    elsif job.nil?
      worker.stales += 1
      Pool.log.verbose "Stale from #{worker}."
      return req.respond( false ) && nil
    end
    # Check submit
    raise ArgumentError, "extra_nonce_2 bad size #{submit.extra_nonce_2.inspect}, expected #{worker.extra_nonce_2_size}" if submit.extra_nonce_2.hexsize != worker.extra_nonce_2_size
    raise ArgumentError, "ntime too high #{submit.ntime.inspect}" if submit.ntime > Time.now.to_i && job.ntime < Time.now.to_i
    raise ArgumentError, "ntime too low #{submit.ntime.inspect}" if submit.ntime < job.ntime
    
    # Build share
    share = Share.new( worker, job, submit )
    Pool.log.debug share.inspect
    worker.add_share( share )

    # Check share is valid
    if share.valid_share?
      Pool.log.verbose "Valid share from #{worker.name}."
      req.respond( true )
    else
      Pool.log.verbose "Bad share from #{worker.name} : #{share.to_hash}"
      req.respond( false )
    end

    adjust_difficulty( worker )

    return share
  rescue ArgumentError => err
    Pool.log.warn "[#{worker.name}] Fail on submit : #{err}"
    Pool.log.warn err.backtrace[0]
    req.respond( false ) && nil
  rescue => err
    Pool.log.error err
    Pool.log.error err.backtrace.join("\n")
    Pool.log.error "worker=#{worker.inspect}"
    Pool.log.error "job=#{job.to_a}"
    Pool.log.error "submit=#{submit.to_a}"
    req.respond( false ) && nil
  end

  def hashrate
    @workers.map(&:hashrate).sum
  end

  def rejected_hashrate
    @workers.map(&:invalid_hashrate).sum
  end

  def update_desired_share_rate_per_worker
    return @desired_share_rate_per_worker = DESIRED_GLOBAL_SHARE_RATE.to_f if @workers.empty? 
    @desired_share_rate_per_worker = DESIRED_GLOBAL_SHARE_RATE.to_f / @workers.size
    Pool.log.debug "new desired_share_rate_per_worker = #{@desired_share_rate_per_worker}"
    @desired_share_rate_per_worker
  end

  # diff * 2**32 == le nombre de hash pour trouver un hash <= target
  # diff * 4 * 2**30 =~ diff * 4 * 10**9
  # diff * 4 =~ le nombre de Giga-hash pour trouver un share a cette diff
  # Compute diff
  # => retained diff
  def adjust_difficulty( worker )
    nb_share = worker.shares.size
    return unless nb_share < 5 || nb_share % 5 == 0
    diff = compute_diff( worker )
    Pool.log.debug "`adjust_diff' for #{@name} with #{worker.hashrate/1000}kh => #{diff}"
    worker.next_difficulty = diff
  end

  def compute_diff worker
    worker_hashrate = worker.hashrate.to_f
    diff = worker_hashrate / desired_share_rate_per_worker / 2 ** 32
    nb_share = worker.shares.size
    diff = diff * nb_share / 10 if nb_share < 10
    diff
  end

  def on_worker_pool_changed worker
    @workers.delete( worker )
    Pool.log.verbose "#{name} worker #{worker.name} removed. Now #{@workers.size} workers."
    worker.off( self, 'disconnect' )
    worker.off( self, 'pool_changed' )
    update_desired_share_rate_per_worker

    if @workers.size == 0
      emit( "empty" )
    elsif self.hashrate < ProfitMining.config.min_pool_hashrate
      emit( "low_hashrate" )
    end
  end

  # If keep_last_one is false, remove all jobs before last clean_jobs
  # else keep the also the previous one.
  # => nb job cleaned
  def clean_previous_jobs(keep_last_one=true)
    back_size = @previous_jobs.size
    jobs_tabs = @previous_jobs.values
    i = jobs_tabs.size - 2
    # on remonte jusqu'au previous clean_jobs==true
    i -= 1 while i >= 0 && ! jobs_tabs[i].clean
    return 0 if i < 0
    i -= 1 if keep_last_one && i != 0
    last_clean_job_id = jobs_tabs[i].id
    # et supprime ce qu'il y a avant.
    @previous_jobs.shift while ! @previous_jobs.empty? && @previous_jobs.first.first != last_clean_job_id
    back_size - @previous_jobs.size
  rescue => err
    log.error "%s (%d, %d, %s)" % [err.to_s, @previous_jobs.size, back_size, i, last_clean_job_id]
    @previous_jobs.size - back_size
  end

  def profitability
    return @profitability unless @profitability_timeout < Time.now.to_f
    @profitability_timeout = Time.now.to_f + @profitability_validity
    if @options[:profitability].kind_of?( Numeric )
      @profitability = @options[:profitability]
    elsif @options[:profitability].respond_to?( :call )
      @profitability = @options[:profitability].call
    end
    @profitability.to_f rescue 0.0
  end

  def to_s
    nb_max = 3
    s = "%s : %d workers, %.1f MH/s, %.1f BTC/MHs/day." % [@name, @workers.size, hashrate * 10**-6, profitability]
    return s if @workers.size == 0
    s += " " + @workers[0...nb_max].map(&:name).to_s
    s += "...%d more]" % (@workers.size - nb_max) if @workers.size > nb_max
    s
  end
end
