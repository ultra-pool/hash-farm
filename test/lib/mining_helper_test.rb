# -*- encoding : utf-8 -*-

require 'test_helper'

require "mining_helper"

class MiningHelperTest < ActiveSupport::TestCase
  test "it should split header" do
    block = ["01000000", "0000000000000000000000000000000000000000000000000000000000000000",
      "3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a", "29ab5f49", "ffff001d", "1dac2b7c"]
    assert_equal block, MiningHelper.split_header( block.join )
  end

  test "it should parse header" do
    block = "01000000" + "0000000000000000000000000000000000000000000000000000000000000000" +
      "3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a" + "29ab5f49" + "ffff001d" + "1dac2b7c"
    res = [1, "0000000000000000000000000000000000000000000000000000000000000000".reverse_hex, 
      "3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a".reverse_hex, Time.at( 0x495fab29 ), "1d00ffff", 0x1dac2b7c]
    assert_equal res, MiningHelper.parse_header( block )
  end

  test "it should switch target_to_nbits" do
    target = "00000000ffff0000000000000000000000000000000000000000000000000000"
    assert_equal "1d00ffff", MiningHelper.target_to_nbits( target )
  end

  test "it should switch nbits_to_target" do
    target = "00000000ffff0000000000000000000000000000000000000000000000000000"
    assert_equal target, MiningHelper.nbits_to_target( "1d00ffff" )
  end

  test "it should switch difficulty_1_target" do
    target = 0x00000000ffff0000000000000000000000000000000000000000000000000000
    assert_equal target, MiningHelper.difficulty_1_target
  end

  test "it should switch difficulty_from_target" do
    target1 = "00000000ffff0000000000000000000000000000000000000000000000000000"
    assert_equal 1.0, MiningHelper.difficulty_from_target( target1 )
    target2 = 0x00000000ffff0000000000000000000000000000000000000000000000000000
    assert_equal 1.0, MiningHelper.difficulty_from_target( target2 )
  end

  test "it should switch difficulty_to_target" do
    target = "00000000ffff0000000000000000000000000000000000000000000000000000"
    assert_equal target, MiningHelper.difficulty_to_target( 1.0 )
  end

  test "it should switch difficulty_to_nbits" do
    assert_equal "1d00ffff", MiningHelper.difficulty_to_nbits( 1.0 )
  end

  test "it should compute mrkl_branches" do
    # Litecoin Block #396506
    txs = ["c12ad86433a44a617c4526fcebc44b4d1bd4ab4256b12b4b8efccf5e2c6893d2",
      "9574311dde2a12de742d594085d7faf38a2f716614b68697c1d33df8d55ee4fc", "20973ec1d7cf309d58fec48d18d1e2f73ca57a1b386fb7fff180d939954924c3",
      "be98b72db38563131fb005dbed435a2f9c8952131de8a8526878c986dad2f1cf", "fa53910a029c492ed438eef435760979bf3d3c76cec481699486da605cedbe60",
      "5f075be009ca99eda58ee7b6001f43217304db81c981df8da441a2a593047556", "602164e32e7e5e7510679a649b1736e279889b5f99ccc9255e8cf85a2b577d41",
      "85ffd9676a12da138bee8bc291d727d1bb070e03a2d4b99d635d5ba1f4571967", "4d2684da2c3046ed2e7445d3747b29166419159cb902bd0b36645ab0e74aaa4b",
      "78a951f17914bde7519791418050ecc06b5e1c71536c163648e483244409274c", "f0de3cf957c3c59169b5df84f45cdec3f7364307f96c7dba9fd3fad545e787bd",
      "38eece1723324eedf1e870c8f91ff8f68a543464b17b6a12b58d84f1c4b1e26d", "4200e5b167a96f3db5c4b6bb41b52e9bbdf26133f07d3c0a6e2f8dde50bf6330",
      "a6897c15e8459186aedc98f659c05079ba2936909a2b5cc6f4f526c48ef8e7c5", "2abc674b0d78ba8c21a5bf76cd06715dce48fd6f0e0d2928ccd89824fc561cf0",
      "bb50a327105bde1ff809c4ff06648e58c1c810cd81647632b8fa038d069148cc", "4df89371a5c1bb80d4503bb30cd1f4ac259095482946c303e4011c5106199c78",
      "8de606e328bf606270644ca5a710f2b4de07f44c78f38cc36db1ac5568e36825", "00d42a57281492dfe671ea0c6f1573fda5d1dc2d37d1e05194dfb8bf16dee73f",
      "d91ad8082f3c21c82f3ccf6e976cdae3db33b0f69cdab1f662bf00b9ff9293aa", "52e1efbc7e241454164eaa519f4945ff9bd2ff9e1b7976ed0e4d258cfb87c1db",
      "4283f67258e44eab17246d9cb68d06bd638d43ab4fcd9c656220907e78932849", "820cbc25cd6b8be065439b6b7e804273c5e3ee392a597466749324091e0b672f",
      "a4d1bcdae787bdbd07fe62730c96880d63c1ca2fb020803205bf66f606a2ea8d"]
    branches = [
      "c12ad86433a44a617c4526fcebc44b4d1bd4ab4256b12b4b8efccf5e2c6893d2",
      "47bb93bff92c07a7dfa9e9e6960871d653f2c3c67aeedcc1605a2c29f4eb25a4",
      "3e7bcc7128ce21b6ab3b08965b362ecdaab9edd10d54397a37188c3c9061787b",
      "005ce32e35a0025af8ed462e556b8f0ba38dadbd2a515f42e83ab614cb7e9e86",
      "0280e09d7422af5652529204392fbd79b44b4d380ef1119f7abd67aad131c7e8",
    ]
    assert_equal branches, MiningHelper.mrkl_branches( txs )
  end

  test "it should compute mrkl_branches_root" do
    coinbase_tx = "ffde72b3b184790f9ab27938248b0218d1ebf23b7cbe2a555caf71e3ddcc6062"
    branches = [
      "c12ad86433a44a617c4526fcebc44b4d1bd4ab4256b12b4b8efccf5e2c6893d2",
      "47bb93bff92c07a7dfa9e9e6960871d653f2c3c67aeedcc1605a2c29f4eb25a4",
      "3e7bcc7128ce21b6ab3b08965b362ecdaab9edd10d54397a37188c3c9061787b",
      "005ce32e35a0025af8ed462e556b8f0ba38dadbd2a515f42e83ab614cb7e9e86",
      "0280e09d7422af5652529204392fbd79b44b4d380ef1119f7abd67aad131c7e8",
    ]
    root   = "a650d73fb7a3204ed28b87e30705bf7e4a872f71a8125481dd084a7d6f04078a"

    assert_equal root, MiningHelper.mrkl_branches_root( coinbase_tx, branches )
  end
end
