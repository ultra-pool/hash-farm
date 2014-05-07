# -*- encoding : utf-8 -*-

require 'test_helper'

require "core_extensions"

class CoreExtensionsTest < ActiveSupport::TestCase
  # using CoreExtensions

  test "object should include boolean" do
    # refute Object.instance_methods.include?( :boolean? )
    # using CoreExtensions
    assert Object.instance_methods.include?( :boolean? )

    assert true.boolean?
    assert false.boolean?
    refute 1.boolean?
    refute 0.boolean?
    refute nil.boolean?
    refute "".boolean?
    refute [].boolean?
    refute({}.boolean?)
    refute "true".boolean?
    refute "false".boolean?
  end

  test "numeric should fround" do
    assert_equal 158.0, 158.fround
    assert_equal 158.0, 158.fround(0)
    assert_equal 158.0, 158.fround(1)
    assert_equal 160.0, 158.fround(-1)
    
    assert_equal Float::INFINITY, Float::INFINITY.fround
    assert_equal Float::INFINITY, Float::INFINITY.fround(-1)
    assert_equal Float::INFINITY, Float::INFINITY.fround(1)
  end

  test "numeric should include btc units" do
    assert_equal 1, 1.satoshi
    assert_equal 100, 1.ubtc
    assert_equal 100, 1.µbtc
    assert_equal 100000, 1.mbtc
    assert_equal 100000000, 1.btc

    assert_equal 1, 1.2.satoshi
    assert_equal 120, 1.2.ubtc
    assert_equal 123, 1.234.ubtc
    assert_equal 124, 1.236.ubtc
    assert_equal 120, 1.2.µbtc
    assert_equal 123000, 1.23.mbtc
    assert_equal 123000000, 1.23.btc
  end

  test "numeric should include btc units" do
    assert_equal 10**3, 1.to_mbtc
    assert_equal 1.2 * 10**3, 1.2.to_mbtc(1)
    assert_equal 10**6, 1.to_ubtc
    assert_equal 10**8, 1.to_satoshi
  end

  test "numeric should include hash units" do
    assert_equal 10**3, 1.khash
    assert_equal 10**6, 1.mhash
    assert_equal 10**9, 1.ghash
  end

  test "integer should include to_hex" do
    # refute Integer.instance_methods.include?( :to_hex )
    # using CoreExtensions
    assert Integer.instance_methods.include?( :to_hex )

    assert_equal "00", 0.to_hex
    assert_equal "00", 0.to_hex(0)
    assert_equal "00", 0.to_hex(1)
    assert_equal "0000", 0.to_hex(2)
    assert_equal "000000", 0.to_hex(3)

    assert_raises ArgumentError do
      1.to_hex(-1)
    end

    assert_equal "01", 1.to_hex
    assert_equal "01", 1.to_hex(1)
    assert_equal "0001", 1.to_hex(2)
    assert_equal "000001", 1.to_hex(3)

    assert_equal "0a", 10.to_hex
    assert_equal "0a", 10.to_hex(1)
    assert_equal "000a", 10.to_hex(2)
    assert_equal "00000a", 10.to_hex(3)

    assert_equal "10", 16.to_hex
    assert_equal "10", 16.to_hex(1)
    assert_equal "0010", 16.to_hex(2)
    assert_equal "000010", 16.to_hex(3)

    assert_equal "0100", 256.to_hex
    assert_equal "0100", 256.to_hex(1)
    assert_equal "0100", 256.to_hex(2)
    assert_equal "000100", 256.to_hex(3)

    assert_equal "-64", -100.to_hex
    assert_equal "-64", -100.to_hex(1)
    assert_equal "-0064", -100.to_hex(2)
    assert_equal "-000064", -100.to_hex(3)

    for n in [0, 1, 10, 16, 256, 100, -100]
      for b in [0, 1, 2, 3, 4, 8]
        assert_equal n, n.to_hex(b).hex
      end
    end
  end

  test "integer should include hash units" do
    assert_equal 12.3, 12345.to_khash
    assert_equal 1.5, 1500000.to_mhash
    assert_equal 123.5, 123450000000.to_ghash
  end

  test "string should include reverse_hex" do
    # refute String.instance_methods.include?( :reverse_hex )
    # using CoreExtensions
    assert String.instance_methods.include?( :reverse_hex )

    assert_equal "", "".reverse_hex
    assert_equal "64", "64".reverse_hex
    assert_equal "A064", "64A0".reverse_hex
    assert_equal "A064F1", "F164A0".reverse_hex

    # Leading and trailing 00
    assert_equal "0000A064F102", "2F164A00000".reverse_hex
    assert_equal "A064F10000", "0000F164A0".reverse_hex

    # Odd number of sign
    assert_equal "A064F102", "2F164A0".reverse_hex

    # Negative number
    assert_equal "-A064F1", "-F164A0".reverse_hex

    # Odd and Negative
    assert_equal "-A064F101", "-1F164A0".reverse_hex

    for n in ['00', '-01', '-A064F102', '-A064F102', '-A064F1020', '-00A064F102000']
      assert_match /0?/, n.reverse_hex.reverse_hex
    end
  end

  # ex : "adbf986000000037".to_bin => "\xAD\xBF\x98`\x00\x00\x007"
  # ex : "\xAD\xBF\x98`\x00\x00\x007".to_hex => "adbf986000000037"
  test "string should include to_bin and to_hex" do
    # refute String.methods.include?( :to_bin )
    # refute String.methods.include?( :to_hex )
    # using CoreExtensions
    assert String.instance_methods.include?( :to_bin )
    assert String.instance_methods.include?( :to_hex )

    data = {
      "adbf986000000037" =>  "\xAD\xBF\x98\x60\x00\x00\x00\x37".force_encoding("ascii"),
      "adbf986000000037" =>  "\xAD\xBF\x98`\x00\x00\x007".force_encoding("ascii"),
      "0000110000" =>  "\x00\x00\x11\x00\x00".force_encoding("ascii"),
      "0000aa0000" =>  "\x00\x00\xaa\x00\x00".force_encoding("ascii"),
      "0000ff0000" =>  "\x00\x00\xff\x00\x00".force_encoding("ascii"),
      "0000000000" =>  "\x00\x00\x00\x00\x00".force_encoding("ascii"),
      "00" =>  "\x00".force_encoding("ascii"),
      "" =>  "",
    }

    # 
    for data_in, data_out in data
      assert_equal data_out, data_in.to_bin, "from hex to bin with in=#{data_in}"
      assert_equal data_in, data_out.to_hex, "from bin to hex with in=#{data_in}"
      assert_equal data_in, data_in.to_bin.to_hex, "from hex to bin to hex with in=#{data_in}"
      assert_equal data_out, data_out.to_hex.to_bin, "from hex to bin to hex to bin with in=#{data_in}"
    end
  end

  # def test_hexsize
  test "string should include hexsize" do
    # refute String.methods.include?( :hexsize )
    # using CoreExtensions
    assert String.instance_methods.include?( :hexsize )

    assert_equal 0, "".hexsize
    assert_equal 1, "1".hexsize
    assert_equal 1, "0".hexsize
    assert_equal 1, "1f".hexsize
    assert_equal 1, "00".hexsize
    assert_equal 2, "01f".hexsize
    assert_equal 2, "001f".hexsize
    assert_equal 3, "1001f".hexsize

    assert_equal 1, "-1".hexsize
    assert_equal 1, "-1f".hexsize
    assert_equal 2, "-001f".hexsize
  end

  test "string should include hex?" do
    # refute String.methods.include?( :hex? )
    # using CoreExtensions
    assert String.instance_methods.include?( :hex? )

    assert "001f".hex?
    assert "1001F".hex?
    assert "A001F".hex?
    assert "A001F".hex?
    assert "0A001F".hex?
    assert "-A001F".hex?
    assert "-0A001F".hex?

    refute "".hex?
    refute "-".hex?
    refute "0a001F".hex?
    refute "a001F".hex?
    refute "-0a001F".hex?
    refute "0G".hex?
  end

  test "string should include reverse_int_hex" do
    # refute String.methods.include?( :reverse_int_hex )
    # using CoreExtensions
    assert String.instance_methods.include?( :reverse_int_hex )

    assert_raises ArgumentError do
      "".reverse_int_hex
    end
    for i in [62, 63, 65]
      assert_raises ArgumentError do
        ("0" * i).reverse_int_hex
      end
    end

    input  = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    output = "03020100070605040b0a09080f0e0d0c13121110171615141b1a19181f1e1d1c"
    assert_equal output, input.reverse_int_hex
  end
  
  test "string should include reverse_hash_int" do
    # refute String.methods.include?( :reverse_hash_int )
    # using CoreExtensions
    assert String.instance_methods.include?( :reverse_hash_int )

    assert_raises ArgumentError do
      "".reverse_hash_int
    end
    for i in [62, 63, 65]
      assert_raises ArgumentError do
        ("0" * i).reverse_hash_int
      end
    end

    input  = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    output = "1c1d1e1f18191a1b14151617101112130c0d0e0f08090a0b0405060700010203"
    assert_equal output, input.reverse_hash_int
  end
  
  test "hash should include compact" do
    # refute Hash.methods.include?( :compact )
    # using CoreExtensions
    assert Hash.instance_methods.include?( :compact )

    assert_equal({}, {}.compact)
    assert_equal({}, {foo: nil}.compact)
    assert_equal({foo: 42}, {foo: 42}.compact)
    assert_equal({}, {foo: nil, bar: nil}.compact)
    assert_equal({bar: 42}, {foo: nil, bar: 42}.compact)
  end

  test "hash should include to_h" do
    # skip if Hash.instance_methods.include?( :to_h )
    # using CoreExtensions
    assert Hash.instance_methods.include?( :to_h )

    assert_equal( {foo: 42, bar: 3.14}, [[:foo, 42], [:bar, 3.14]].to_h )
  end
  
  test "openstruct should include delete" do
    # refute OpenStruct.methods.include?( :delete )
    # using CoreExtensions
    assert OpenStruct.instance_methods.include?( :delete )

    assert_raises NameError do OpenStruct.new.delete_field(:bar) end
    assert_nil OpenStruct.new.delete(:bar)
    o = OpenStruct.new(foo: 42)
    assert_nil o.delete(:bar)
    assert_equal 42, o.delete(:foo)
    assert_nil o.delete(:foo)
  end
end