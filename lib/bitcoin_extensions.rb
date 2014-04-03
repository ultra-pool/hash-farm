# -*- encoding : utf-8 -*-

require 'bitcoin'
require 'bitcoin/litecoin'
require 'core_extensions'
require 'mining_helper'

module Bitcoin
  using CoreExtensions

  class Script
    # If data is an integer, convert it to binary data little-endian encoded.
    # If data is an hexadecimal string (supposed big-endian), convert it to binary data little-endian encoded
    # Otherwise, just give it as a string
    def self.pack_push_var_data(data)
      case data
      when Integer
        data = "%x" % [data]
        data = (data.size % 2 == 1 ? '0' : '') + data
        data = [data].pack("H*").reverse
      when String
        data = [data].pack("H*").reverse if data =~ /^([0-9a-fA-f]{2})+$/ # => Hexadecimal
      else
        data = data.to_s
      end
      pack_pushdata data
    end

    def self.coinbase(*args)
      args.map { |data| pack_push_var_data data }.join
    end
  end

  def self.dblsha( hex )
    Digest::SHA256.digest( Digest::SHA256.digest( [hex].pack("H*") ) ).unpack("H*")[0].reverse_hex
  end
  
  def self.pack_int(n)
    b = [1]
    while n > 127
      b[0] += 1
      b << (n %256)
      n /= 256
    end
    (b << n).pack("C*")
  end

  # => [version, hash, valid]
  def self.parse_address( addr )
    version, hash, check = decode_base58( addr ).scan( /^(\w{2})(\w{40})(\w{8})$/ ).first
    return if hash.nil?
    [version, hash, check == checksum(version+hash)]
  end

  # Overwrite to handle altcoins
  def self.to_address_script( addr )
    hash160 = hash160_from_address( address )
    to_hash160_script( hash160 )
  end

  # def self.nbits_to_difficulty( nbits )
  #   mantisse, base = nbits.scan(/(\w\w)((?:\w\w){2,})/).first.map(&:hex)
  #   BigDecimal.new( base ) * 2**( 8 * ( mantisse - 3 ) )
  # end
end # module bitcoin
