# -*- encoding : utf-8 -*-

require 'core_extensions'
require 'loggable'

# using CoreExtensions

module Stratum
  class Submit
    include Loggable

    # Strings
    attr_reader :worker, :job_id, :extra_nonce_2
    # Integers
    attr_reader :ntime, :nonce

    def initialize( worker, job_id, extra_nonce_2, ntime, nonce )
      @worker, @job_id, @extra_nonce_2 = worker, job_id, extra_nonce_2
      @ntime, @nonce = ntime.hex, nonce.reverse_hex.hex
      t = Time.at( @ntime )
      log.warn "ntime is not good date #{t} (reverse => #{Time.at @ntime.to_hex(4).reverse_hex.hex}, ntime=#{@ntime})" if t > Time.now + 3600 * 2 || t < Time.now - 3600 * 2
    end

    def to_a
      [@worker, @job_id, @extra_nonce_2, @ntime, @nonce]
    end

    def to_stratum
      [@worker.fullname, @job_id, @extra_nonce_2, @ntime.to_hex(4), @nonce.to_hex(4).reverse_hex]
    end
  end
end # module Stratum