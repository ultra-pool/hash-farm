# -*- encoding : utf-8 -*-

require "core_extensions"
require 'mining_helper'
require "loggable"

using CoreExtensions

class BlockHeader
  include Loggable

  attr_reader :version, :previous_hash, :merkle_root, :nbits, :ntime, :nonce

  # 
  # version, ntime, nbits and nonce or Integers
  # previous_hash and merkle_root are Hex String in Big Endian (0s first)
  def initialize( _version, _previous_hash, _merkle_root, _ntime, _nbits, _nonce )
    check_params( _version, _previous_hash, _merkle_root, _ntime, _nbits, _nonce )
    @version, @previous_hash, @merkle_root, @ntime, @nbits, @nonce = _version, _previous_hash, _merkle_root, _ntime, _nbits, _nonce
  end

  def check_params _version, _previous_hash, _merkle_root, _ntime, _nbits, _nonce
    raise ArgumentError unless _version.kind_of?( Integer )
    raise ArgumentError unless _previous_hash.kind_of?( String ) && _previous_hash.hexsize == 32
    # raise ArgumentError unless previous_hash[0...8] == "00000000" # For diff >= 1
    raise ArgumentError unless _merkle_root.kind_of?( String ) && _merkle_root.hexsize == 32
    raise ArgumentError unless _ntime.kind_of?( Integer )
    raise ArgumentError unless _nbits.kind_of?( Integer )
    raise ArgumentError unless _nonce.kind_of?( Integer )
  end

  def to_hex
    # return @hex if @hex
    # version 4bytes little-endian + prev block hash 32bytes (little endian ?) + merkle root 32bytes (little endian ?) +
    # timestamp 4bytes little-endian + bits 4bytes little-endian + nonce 4bytes BIG-ENDIAN ! = 80 bytes
    @hex  = @version.to_hex(4).reverse_hex
    @hex += @previous_hash.reverse_hex
    @hex += @merkle_root.reverse_hex
    @hex += @ntime.to_hex(4).reverse_hex
    @hex += @nbits.to_hex(4).reverse_hex
    @hex += @nonce.to_hex(4).reverse_hex
    return @hex
  end

  def scrypt_hash
    @scrypt_hash ||= ScryptHelper.to_hash( self.to_hex )
  end

  def sha_hash
    @sha_hash ||= Bitcoin.dblsha( self.to_hex )
  end

  def to_hash(algo=:scrypt)
    if algo == :scrypt
      scrypt_hash
    elsif algo == :sha256
      sha_hash
    end
  end

  def target
    @target ||= Bitcoin.decode_compact_bits( @nbits )
  end

  def match_difficulty( diff )
    to_hash <= MiningHelper.difficulty_to_target( diff )
  end

  def is_valid_block?
    res = to_hash.hex <= target.hex
    log.debug "`is_valid_block?' => false #{to_hash} not <= to #{target}" if ! res
    res
  end

  def inspect
    [@version, @previous_hash, @merkle_root, @ntime, @nbits, @nonce].inspect
  end

  def to_s
    s  = "BlockHeader["
    s += @version.to_hex(4).reverse_hex + '|'
    s += "..." + @previous_hash[-8..-1] + '|'
    s += @merkle_root[0..7] + '...|'
    s += @nbits.to_hex(4).reverse_hex + '|'
    s += @ntime.to_hex(4).reverse_hex + '|'
    s += @nonce.to_hex(4).reverse_hex
    s += ']'
  end

  # To send this share to getblocktemplate :
  # Block Submission
  #
  # A JSON-RPC method is defined, called "submitblock", to submit potential blocks (or shares).
  # It accepts two arguments: the first is always a String of the hex-encoded block data to submit;
  # the second is an Object of parameters, and is optional if parameters are not needed.
  #
  # To assemble the block data, simply concatenate your block header,
  # number of transactions encoded in Bitcoin varint format,
  # followed by each of the transactions in your block (beginning with the coinbase).
  # If the server has listed "submit/coinbase" in its "mutable" key,
  # you may opt to omit the transactions after the coinbase.
  #
  # Python example:
  #
  # def varintEncode(n):
  #   if n < 0xfd:
  #     return struct.pack('<B', n)
  #   # NOTE: Technically, there are more encodings for numbers bigger than
  #   # 16-bit, but transaction counts can't be that high with version 2 Bitcoin
  #   # blocks
  #   return b'\xfd' + struct.pack('<H', n)
  # blkdata = blkheader + varintEncode(len(txnlist)) + coinbase
  # if 'submit/coinbase' not in template.get('mutable', ()):
  #   for txn in txnlist[1:]:
  #     blkdata += txn
  #
  def to_json
    raise "Not yet implemented."
  end
end

class ShareTool < BlockHeader
  include Loggable

  attr_reader :worker_name, :worker_difficulty
  # :coinb1, :coinb2, :extra_nonce_1, :extra_nonce_2 are big-endian hex strings
  attr_reader :coinb1, :coinb2, :extra_nonce_1, :extra_nonce_2, :merkle_branches
  # Integer, job timestamp
  attr_reader :jtime
  # String
  attr_reader :job_id
  attr_reader :created_at, :job, :worker, :submit

  def initialize( worker, job, submit )
    @created_at = Time.now
    @job, @submit = job, submit

    @worker_name = worker.name
    @extra_nonce_1 = worker.extra_nonce_1

    @job_id, _previous_hash, @coinb1, @coinb2, @merkle_branches, _version, _nbits, @jtime = ShareTool.decode_job( job )
    @extra_nonce_2, _ntime, _nonce = ShareTool.decode_submit( submit )
    
    @worker_difficulty = worker.jobs_pdiff[ @job_id ]
    _merkle_root = MiningHelper.mrkl_branches_root( coinbase_hash, @merkle_branches ) # already reversed

    super( _version, _previous_hash, _merkle_root, _ntime, _nbits, _nonce )
  end

  # Transform previous_hash from little to big endian,
  # version and nbits from little endian hex string to Integer
  def self.decode_job( job )
    _job_id, _previous_hash, _coinb1, _coinb2, _merkle_branches, _version, _nbits, _jtime = *job
    _previous_hash = _previous_hash.reverse_hash_int
    _merkle_branches = _merkle_branches.map { |h| h.reverse_hex }
    _version       = _version.hex
    _nbits         = _nbits.hex
    _jtime         = _jtime.hex
    [_job_id, _previous_hash, _coinb1, _coinb2, _merkle_branches, _version, _nbits, _jtime]
  end

  # Transform previous_hash from little to big endian,
  # Transform ntime and nonce from little endian hex string to Integer
  def self.decode_submit( submit )
    _extra_nonce_2, _ntime, _nonce = *submit
    # _extra_nonce_2 = _extra_nonce_2.reverse_hex
    _ntime = _ntime.hex
    _nonce = _nonce.hex
    t = Time.at( _ntime )
    log.warn "ntime is not good date #{t} (reverse => #{Time.at _ntime.to_hex(4).reverse_hex.hex}, jtime=#{@jtime})" if t > Time.now + 3600 * 2 || t < Time.now - 3600 * 2
    [_extra_nonce_2, _ntime, _nonce]
  end

  def extra_nonce
    @extra_nonce_1 + @extra_nonce_2
  end

  def coinbase_hex
    @coinb1 + extra_nonce + @coinb2
  end

  def coinbase_hash
    Bitcoin.dblsha( coinbase_hex )
  end

  def share_target
    # coin.difficulty_to_target( @worker_difficulty )
    @share_target ||= MiningHelper.difficulty_to_target( @worker_difficulty )
  rescue
    log.error "in `share_target' with worker_difficulty=#{@worker_difficulty.inspect}"
    raise
  end

  def is_valid_share?
    res = to_hash.hex <= share_target.hex
    log.debug "Bad share #{to_hash} not <= to #{share_target}" if ! res
    res
  end

  def inspect
    {
      header: super,
      worker_name: @worker_name,
      worker_difficulty: @worker_difficulty,
      extra_nonce_1: @extra_nonce_1,
      extra_nonce_2: @extra_nonce_2,
    }.inspect
  end

  def to_s
    s  = super
    s += "/Share["
    s += @worker_name[0..7] + '...|'
    s += @worker_difficulty.to_s + '|'
    s += @extra_nonce_1 + '|'
    s += @extra_nonce_2 + '|'
    s += "]"
    s
  end
end
