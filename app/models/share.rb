# -*- encoding : utf-8 -*-

require 'core_extensions'
require 'mining_helper'

using CoreExtensions

class Share < ActiveRecord::Base
  belongs_to :worker
  belongs_to :payout
  has_one :user, through: :worker

  scope :unpaid, -> { where(payout_id: nil) }
  scope :accepted, -> { where(our_result: true) }

  attr_reader :version, :previous_hash, :merkle_root, :nbits, :ntime, :nonce
  # :coinb1, :coinb2, :extra_nonce_1, :extra_nonce_2 are big-endian hex strings
  attr_reader :coinb1, :coinb2, :extra_nonce_1, :extra_nonce_2, :merkle_branches
  # Integer, job timestamp
  attr_reader :jtime
  # String
  attr_reader :job_id
  attr_reader :job, :submit
  # Float
  attr_reader :worker_difficulty

  # Share.new( worker, job, submit )
  def initialize( *args, **kargs )
    super(**kargs)
    self.created_at = Time.now
    if args.size == 3 && args[1].kind_of?( Stratum::Job ) && args[2].kind_of?( Stratum::Submit )
      worker, @job, @submit = *args
      @extra_nonce_1 = worker.extra_nonce_1
      @job_id, @previous_hash, @coinb1, @coinb2, @merkle_branches, @version, @nbits, @jtime, clean, pdiff = *@job.to_a
      _, _, @extra_nonce_2, @ntime, @nonce = *@submit.to_a
      @worker_difficulty = worker.jobs_pdiff[ @job_id ]

      check_params

      self.pool = job.pool
      self.worker_id = worker.model.id
      self.difficulty = worker.jobs_pdiff[ @job_id ]
      self.solution = to_hash
      self.our_result = match_difficulty( self.difficulty )
      self.is_block = match_nbits( @nbits )
    end
  end

  def match_difficulty( diff )
    solution <= MiningHelper.difficulty_to_target( diff )
  end

  def match_nbits( nbits )
    solution <= Bitcoin.decode_compact_bits( nbits )
  end

  def valid_share?
    self.our_result
  end

  def valid_block?
    raise unless @nbits
    match_nbits( @nbits )
  end

  # private

    def extra_nonce
      @extra_nonce_1 + @extra_nonce_2
    end

    def coinbase_hex
      @coinb1 + extra_nonce + @coinb2
    end

    def coinbase_hash
      Bitcoin.dblsha( coinbase_hex )
    end

    def merkle_root
      MiningHelper.mrkl_branches_root( coinbase_hash, @merkle_branches ) # ? .map { |h| h.reverse_hex } ou tests faux
    end

    def check_params
      raise ArgumentError unless @version.kind_of?( Integer )
      raise ArgumentError unless @previous_hash.kind_of?( String ) && @previous_hash.hexsize == 32
      raise ArgumentError unless @ntime.kind_of?( Integer )
      raise ArgumentError unless @nbits.kind_of?( Integer )
      raise ArgumentError unless @nonce.kind_of?( Integer )
    end

    def to_hex
      # return @hex if @hex
      # version 4bytes little-endian + prev block hash 32bytes (little endian ?) + merkle root 32bytes (little endian ?) +
      # timestamp 4bytes little-endian + bits 4bytes little-endian + nonce 4bytes BIG-ENDIAN ! = 80 bytes
      @hex  = @version.to_hex(4).reverse_hex
      @hex += @previous_hash.reverse_hex
      @hex += merkle_root.reverse_hex
      @hex += @ntime.to_hex(4).reverse_hex
      @hex += @nbits.to_hex(4).reverse_hex
      @hex += @nonce.to_hex(4)
      return @hex
    end

    def scrypt_hash
      @scrypt_hash ||= ScryptHelper.to_hash( to_hex )
    end

    def sha_hash
      @sha_hash ||= Bitcoin.dblsha( to_hex )
    end

    def to_hash(algo=:scrypt)
      if algo == :scrypt
        scrypt_hash
      elsif algo == :sha256
        sha_hash
      end
    end

    def ident
      to_hash.sub(/^0+/,'')[0...8]
    end
  # end private
end
