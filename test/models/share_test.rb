require 'test_helper'

require 'ostruct'
require "protocol/stratum/job"
require "protocol/stratum/submit"
require "core/share_tool"

using CoreExtensions

class ShareTest < ActiveSupport::TestCase

  setup do
    # Block #396506
    @version       = 2
    @previous_hash = "391e4170f227b00db87b381b351d9371794aa629b092732298717111c271124c"
    @ntime         = 1374999143
    @nbits         = "1b47c7ea".hex
    @nonce         = 14575193
    @extra_nonce_1 = "917f0000"
    @extra_nonce_2 = "89000000"
    @extra_nonce   = @extra_nonce_1 + @extra_nonce_2
    @extra_nonce_2_size = @extra_nonce_2.hexsize

    @script1       = "03" + "da0c06" + "0651f4d267018cd0335c9e"
    @script2       = ""
    @coinb1        = "01000000" + "01" + Bitcoin::Protocol::TxIn::NULL_HASH.unpack("H*")[0] + "%x" % Bitcoin::Protocol::TxIn::COINBASE_INDEX + "17" + @script1
    @coinb2        = @script2 + "ffffffff" + "01" + "a0a92d2a01000000" + "19"+ "76a9143bb598947d1dbf04ec724c41272548b" + "04af487af88ac" + "00000000"
    @coinbase_hex  = @coinb1 + @extra_nonce + @coinb2
    @coinbase_hash = "ffde72b3b184790f9ab27938248b0218d1ebf23b7cbe2a555caf71e3ddcc6062"
    @coinbase_hex  = "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff1703da0c060651f4d267018cd0335c9e917f000089000000ffffffff01a0a92d2a010000001976a9143bb598947d1dbf04ec724c41272548b04af487af88ac00000000"

    @merkle_branches = [
      "c12ad86433a44a617c4526fcebc44b4d1bd4ab4256b12b4b8efccf5e2c6893d2",
      "47bb93bff92c07a7dfa9e9e6960871d653f2c3c67aeedcc1605a2c29f4eb25a4",
      "3e7bcc7128ce21b6ab3b08965b362ecdaab9edd10d54397a37188c3c9061787b",
      "005ce32e35a0025af8ed462e556b8f0ba38dadbd2a515f42e83ab614cb7e9e86",
      "0280e09d7422af5652529204392fbd79b44b4d380ef1119f7abd67aad131c7e8",
    ]

    @merkle_root   = "a650d73fb7a3204ed28b87e30705bf7e4a872f71a8125481dd084a7d6f04078a"
    @block_hash    = "00000000002bef4107f882f6115e0b01f348d21195dacd3582aa2dabd7985806"

    @worker = OpenStruct.new(
      model: workers(:one),
      difficulty: 1,
      extra_nonce_1: @extra_nonce_1,
      extra_nonce_2_size: @extra_nonce_2_size,
      jobs_pdiff: {"a" => 1}
    )
    @job = Stratum::Job.new( "a", @previous_hash, @coinb1, @coinb2, @merkle_branches, @version, @nbits, @ntime-10, true )
    @submit = Stratum::Submit.new( "toto", "a", @extra_nonce_2, @ntime.to_hex(4), @nonce.to_hex(4).reverse_hex )

    @share = Share.new( @worker, @job, @submit )
  end

  test "initialize" do
    assert_equal @worker.model.name, @share.worker.name
    assert_equal @worker.extra_nonce_2_size, @share.extra_nonce_2.hexsize

    assert_equal @extra_nonce_1, @share.extra_nonce_1
    
    assert_equal @previous_hash, @share.previous_hash
    assert_equal @coinb1, @share.coinb1
    assert_equal @coinb2, @share.coinb2
    assert_equal @merkle_branches, @share.merkle_branches
    assert_equal @version, @share.version
    assert_equal @nbits, @share.nbits
    
    assert_equal @extra_nonce_2, @share.extra_nonce_2
    assert_equal @ntime, @share.ntime
    assert_equal @ntime - 10, @share.jtime
    assert_equal @nonce, @share.nonce

    assert_equal @extra_nonce, @share.extra_nonce
    assert_kind_of String, @share.merkle_root
  end

  test "extra_nonce" do
    assert_equal @extra_nonce, @share.extra_nonce
  end

  test "coinbase_hex" do
    assert_equal @coinbase_hex, @share.coinbase_hex
  end

  test "coinbase_hash" do
    assert_equal @coinbase_hash, @share.coinbase_hash
  end

  test "merkle_root" do
    assert_equal @merkle_root, @share.merkle_root
  end

  test "to_hex" do
    hex = @version.to_hex(4).reverse_hex + @previous_hash.reverse_hex + @merkle_root.reverse_hex
    hex += @ntime.to_hex(4).reverse_hex + @nbits.to_hex(4).reverse_hex + @nonce.to_hex(4)
    share_hex = @share.to_hex
    assert_equal hex, share_hex

    version, previous_hash, merkle_root, ntime, nbits, nonce = *share_hex.to_bin.unpack("L<a32a32L<L<L>")
    assert_equal @version, version
    assert_equal @previous_hash, previous_hash.reverse.to_hex
    assert_equal @merkle_root, merkle_root.reverse.to_hex
    assert_equal @ntime, ntime
    assert_equal @nbits, nbits
    assert_equal @nonce, nonce
  end

  test "to_hash" do
    assert_equal @block_hash, @share.to_hash
  end

  test "it should be a valid share" do
    assert @share.our_result
    assert @share.valid?
  end

  test "it should not be a valid share" do
    share = Share.new(
      worker_id: @worker.model.id,
      difficulty: 1,
      solution: "00000000ffff0000000000000000000000000000000000000000000000000001",
    )
    share.our_result = share.match_difficulty( share.difficulty )
    share.is_block = share.match_nbits( @nbits )

    refute share.our_result
    refute share.valid_share?
  end

  def valid_block?
    assert @share.is_valid_block?
    
    share = ShareTool.new( @worker, @job, @submit )
    
    # == share_target, share_diff == 1
    share.stubs(to_hash: "00000000ffff0000000000000000000000000000000000000000000000000000")
    refute share.is_valid_block?
    # == block_target
    target = Bitcoin.decode_compact_bits @nbits.hex
    share.stubs(to_hash: target)
    assert share.is_valid_block?
    # == block_target + 1
    target = (target.hex + 1).to_hex(32)
    share.stubs(to_hash: target)
    refute share.is_valid_block?
  end

  def genesis_share
    # skip("Must be adapted to Litecoin Genesis instead of Bitcoin Genesis")
    version     = 1
    previous_hash  = 0x0000000000000000000000000000000000000000000000000000000000000000
    merkle_root   = 0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b
    block_hash  = 0x000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f
    ntime    = 1231006505
    nbits    = 0x1d00ffff # difficulty 1
    nonce   = 2083236893

    extra_nonce = "04"
    script1 = "04ffff001d01"
    script2 = "455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73"
    script = script1 + extra_nonce + script2
    coinb1 = "01000000" + "01" + "0000000000000000000000000000000000000000000000000000000000000000ffffffff" + "4d" + script1
    coinb2 = script2 + "ffffffff"+ "01" + "00f2052a01000000" + "43" + "4104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac" + "00000000"
    coinb = coinb1 + extra_nonce + coinb2
    coinbase_hash = "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b"

    block_hex = "01000000" + "0000000000000000000000000000000000000000000000000000000000000000"
    block_hex+= "3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a" + "29ab5f49" + "ffff001d" + "1dac2b7c"

    worker = OpenStruct.new( name: "", extra_nonce_1: '', jobs_pdiff: {"a" => 1}, model: {} )
    job = ["a", previous_hash.to_hex(32).reverse_hash_int, coinb1, coinb2, [], version.to_hex(4), nbits.to_hex(4), ntime.to_hex(4)]
    submit = ["04", ntime.to_hex(4), nonce.to_hex(4)]

    share = ShareTool.new( worker, job, submit )

    assert_equal "04", share.extra_nonce
    assert_equal coinb, share.coinbase_hex
    assert_equal coinbase_hash, share.coinbase_hash
    assert_equal block_hex, share.to_hex
    assert_equal block_hash.to_hex(32), share.to_hash(:sha256)
  end

  def elephant_block
    # Block #873875 from ElephantCoin found by us (from NodeJS)
    @worker.extra_nonce_1 = "1fffffff"
    @worker.jobs_pdiff['20'] = 2**-10
    job = ['20', '04c688626733e07faddf80cc9595dc96120c95101bd27481d2bc329f1a273ccf',
      '01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff270393550d062f503253482f040e54145308',
      '0d2f6e6f64655374726174756d2f000000000100f2052a010000001976a91468774ccce28e268ff0d350d8c4978c48c2e06c2488ac00000000',
      [], '00000001', '1d094448', '531453ef', false]
    submit = [
      '186e2PUgDoEZ14t25wYN8x1Ry5gtV3Qvj1',
      '20', '00000000', '531453ef', '0b327766' ]
    share = ShareTool.new( @worker, job, submit[2..-1] )

    coinbaseBuffer = "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff270393550d062f503253482f040e541453081fffffff000000000d2f6e6f64655374726174756d2f000000000100f2052a010000001976a91468774ccce28e268ff0d350d8c4978c48c2e06c2488ac00000000" 
    coinbaseHash = "3f6cb48f87404b527c050f889da2e0110fef53c7c5a72f1928b745bd29519ffc" 
    merkleRoot = "fc9f5129bd45b728192fa7c5c753ef0f11e0a29d880f057c524b40878fb46c3f" 
    headerHash = "2cafd4ed55676991f0777058fef290710887fa2055816cf0f61514a805000000" 
    blockHex = "010000006288c6047fe03367cc80dfad96dc959510950c128174d21b9f32bcd2cf3c271a3f6cb48f87404b527c050f889da2e0110fef53c7c5a72f1928b745bd29519ffcef5314534844091d6677320b0101000000010000000000000000000000000000000000000000000000000000000000000000ffffffff270393550d062f503253482f040e541453081fffffff000000000d2f6e6f64655374726174756d2f000000000100f2052a010000001976a91468774ccce28e268ff0d350d8c4978c48c2e06c2488ac00000000"

    assert share.is_valid_share?
    assert share.is_valid_block?

    assert_equal coinbaseBuffer, share.coinbase_hex
    assert_equal blockHex[0...160], share.to_hex
    assert_equal blockHex, share.to_hex + "01" + share.coinbase_hex
  end

  def merkle_root
    worker = OpenStruct.new(extra_nonce_1: "1b0056e2", extra_nonce_2_size: 4, name: "toto", jobs_pdiff: {"8ea" => 0.006})
    job = ["8ea",
      "2dd053e43342e5ef9e1d638dc994a5733311a8d8dd52cb152a4002043be51357",
      "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff2703071e02062f503253482f048c91215308",
      "0d2f6e6f64655374726174756d2f00000000010041ca347f2700001976a914312f0edfb1647e2f9ddbc6a0faacf3c3c8d1d21588ac00000000",
      ["db84846f8a5b15569313e87c03603ce60f54101a160fa591aa08da06ddfdcb38",
        "a377e0ce2ef56b920cdca5a69828f35a6383d3dafb03c462c94323a701a0e683",
        "b5b8efa43d39f098e1742926da8ab128a48b613a0b9e16e449ec1004f9a1be63"],
      "00000002",
      "1b3d1143",
      "5321918b",
      true]
    submit = ["0d000000", "5321918b", "793e0e00"]
    share = ShareTool.new( worker, job, submit )

    assert_equal "ccdac3c250c61c778afcd037bbb3a858de61f804282291172a180c5993a40e5a", share.coinbase_hash, share.inspect
    assert_equal "8813f3c7b3b6fbfbe2bf858b3ee9ebcdae0249ecc361b43b203cec7e5ef1a8f3", share.merkle_root, share.inspect
    assert_equal "0000004ba3a8a6b2400b0f1f03636d73933fadd991f75adf5ec2b582957926d1", share.to_hash, share.inspect
  end
end