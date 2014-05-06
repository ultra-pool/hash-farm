# -*- encoding : utf-8 -*-

require 'core_extensions'

# using CoreExtensions

module Stratum
  class Job
    def self.from_stratum( ary )
      id, prev_hash, coinb1, coinb2, merkle_branches, version, nbits, ntime, clean = *ary
      self.new(
        id,
        prev_hash.reverse_hash_int,
        coinb1,
        coinb2,
        merkle_branches.map { |h| h.reverse_hex },
        version.hex,
        nbits.hex,
        ntime.hex,
        clean
      )
    end

    # Strings
    attr_reader :id, :prev_hash, :coinb1, :coinb2
    # Array of String BE Hex
    attr_reader :merkle_branches
    # Integers
    attr_reader :version, :nbits, :ntime
    # Boolean
    attr_reader :clean
    # Time
    attr_reader :created_at
    # Which pool owns this job
    attr_accessor :pool

    def initialize( id, prev_hash, coinb1, coinb2, merkle_branches, version, nbits, ntime, clean )
      @created_at = Time.now
      @id, @prev_hash, @coinb1, @coinb2, @merkle_branches, @version, @nbits, @ntime, @clean = 
        id, prev_hash, coinb1, coinb2, merkle_branches, version, nbits, ntime, clean
    end

    def to_a
      [@id, @prev_hash, @coinb1, @coinb2, @merkle_branches, @version, @nbits, @ntime, @clean]
    end

    def to_s
      "#<Stratum::Job:#{id}@#{Time.at(ntime)}>"
    end
    def inspect
      to_s
    end

    def to_stratum
      [
        @id,
        @prev_hash.reverse_hash_int, # first 4 bytes become 4 last bytes.
        @coinb1,
        @coinb2,
        @merkle_branches.map { |h| h.reverse_hex }, # To LE Hex
        @version.to_hex(4),
        @nbits.to_hex(4),
        @ntime.to_hex(4),
        @clean,
      ]
    end
  end
end # module Stratum
