# -*- encoding : utf-8 -*-

require 'bitcoin'
require 'scrypt'
require 'bitcoin_extensions'

# using CoreExtensions

module MiningHelper

  ######   HEADERS  HELPERS   #######

  def self.split_header( header_hex )
    header_hex.scan(/(\w{8})(\w{64})(\w{64})(\w{8})(\w{8})(\w{8})/)[0]
  end

  def self.parse_header( header_hex )
    version, prev_hash, merkle_root, ntime, nbits, nonce = split_header( header_hex ).map { |h| h.reverse_hex }
    [version.hex, prev_hash, merkle_root, Time.at(ntime.hex), nbits, nonce.reverse_hex.hex]
  end


  ######   TARGET / NBITS / DIFFICULTY SWITCHERS   #######

  # target an Integer or a String HexBE encoded
  # => str
  def self.target_to_nbits( target )
    target = target.to_hex(32) if target.kind_of?( Integer )
    Bitcoin.encode_compact_bits( target ).to_hex(4)
  end

  # => str (Hex encoded BE, 32 Bytes)
  def self.nbits_to_target( nbits )
    nbits = nbits.hex if nbits.kind_of?( String )
    Bitcoin.decode_compact_bits( nbits )
  end

  # => int
  def self.difficulty_1_target
    0x00000000FFFF0000000000000000000000000000000000000000000000000000
  end

  # target an Integer or a String HexBE encoded
  # => float
  def self.difficulty_from_target( target )
    target = target.hex if target.kind_of?( String )
    (BigDecimal.new( difficulty_1_target ) / target.to_f).to_f
  end

  # diff a float
  # => str (Hex encoded BE, 32 Bytes)
  def self.difficulty_to_target( diff )
    ( difficulty_1_target / diff.to_f ).to_i.to_hex(32)
  end

  # diff a float
  # => fix
  def self.difficulty_to_nbits( diff )
    nbits_from_target( target_from_difficulty( diff ) )
  end

  class << self
    alias_method :nbits_from_target, :target_to_nbits
    alias_method :target_from_nbits, :nbits_to_target

    alias_method :target_to_difficulty, :difficulty_from_target
    alias_method :target_from_difficulty, :difficulty_to_target
    alias_method :nbits_from_difficulty, :difficulty_to_nbits
  end


  ######     MERKLE  BRANCHES  /  MERKLE  ROOT    ######

  # hashes is an Array of little-endian encoded transactions' hash
  def self.mrkl_branches( hashes )
    hashes = hashes.dup
    return [] if hashes.empty?
    branches = [hashes.shift]
    while hashes && hashes.size >= 1
      first, *hashes = hashes.each_slice(2).map { |a, b| Bitcoin.bitcoin_mrkl( a, b || a ) }
      branches << first
    end
    branches
  end

  # branches is the Array return by mrkl_branches (big-endian encoded hashes)
  def self.mrkl_branches_root( coinbase_hash, branch_hashes )
    branch_hashes.inject(coinbase_hash) { |r, h| Bitcoin.bitcoin_mrkl( r, h ) }
  end


  ######   HASH  HELPERS   #######

  def self.dblsha( hex )
    Digest::SHA256.digest( Digest::SHA256.digest( [hex].pack("H*") ) ).unpack("H*")[0].reverse_hex
  end

  def self.scrypt( hex )
    Scrypt.hash_hex( hex )
    # Litecoin::Scrypt.scrypt_1024_1_1_256( hex )
  end

  def self.hash_payout( inputs, outputs )
    dblsha(
      inputs.map { |h| h.values.join(',') }.sort.join("\n") +
      "---\n" +
      outputs.map { |t| t.join(',') }.sort.join("\n")
    )
  end

  ######   ADDRESS  HELPERS   #######

  def self.hash160_from_address( addr )
    version, hash, valid = parse_address( addr )
    hash if valid
  end

  # => [version, hash, valid]
  def self.parse_address( addr )
    version, hash, check = Bitcoin.decode_base58( addr ).scan( /^(\w{2})(\w{40})(\w{8})$/ ).first
    [version, hash, check == Bitcoin.checksum(version+hash)]
  end

  def self.coin_addr_type?( addr )
    addr.kind_of?( String ) && addr.match(/^[A-HJ-NP-Za-km-z1-9]{33,34}$/)
  end
end # module MiningHelper


######   SCRYPT  HELPERS   #######

module ScryptHelper
  # include MiningHelper # marche pas à cause des methodes de class

  def self.to_hash( hex )
    Scrypt.hash_hex( hex )
  end

  # difficulty 1
  # nbits = 0x1d00ffff
  # 0xffff * 2**208 * 2**12
  # 0xffff * 2**220
  # (2**236 - 1).round_sur_3_bytes
  def self.initial_target
    0x00000FFFF0000000000000000000000000000000000000000000000000000000
  end

  def self.difficulty_from_nbits( nbits )
    nbits = nbits.hex if nbits.kind_of?( String )
    max_body, scaland = Math.log( 0x0ffff0 ), Math.log(256)
    Math.exp(max_body - Math.log(nbits & 0x00ffffff) + scaland * (0x1e - ((nbits & 0xff000000) >> 24)))
  end


  class << self
    alias_method :nbits_to_difficulty, :difficulty_from_nbits
  end
end # module ScryptHelper

######   SHA-256  HELPERS   #######

module Sha256CoinHelper
  # include MiningHelper # marche pas à cause des methodes de class
  
  def self.to_hash( hex )
    dblsha( hex )
  end

  def self.difficulty_from_nbits( nbits )
    nbits = nbits.hex if nbits.kind_of?( String )
    max_body, scaland = Math.log( 0x00ffff ), Math.log(256)
    Math.exp(max_body - Math.log(nbits & 0x00ffffff) + scaland * (0x1d - ((nbits & 0xff000000) >> 24)))
  end

  class << self
    alias_method :nbits_to_difficulty, :difficulty_from_nbits
  end
end