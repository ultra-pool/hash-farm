# -*- encoding : utf-8 -*-

# module CoreExtensions
  # refine Object do
  class Object
    def boolean?
      self == !!self
    end
  end
  
  class Numeric
    # Always return a float, handle INFINITY
    def fround(precision=0)
      return self if self == Float::INFINITY
      r = self.round(precision)
      r = r.to_f if r.kind_of?( Integer )
      r
    end

    def satoshi
      self.round
    end

    def ubtc
      (self * 10**2).round
    end
    alias_method :µbtc, :ubtc

    def mbtc
      (self * 10**5).round
    end

    def btc
      (self * 10**8).round
    end

    def khash
      (self * 10**3).round
    end

    def mhash
      (self * 10**6).round
    end

    def ghash
      (self * 10**9).round
    end
  end

  # refine Integer do
  class Integer
    # intN.to_hex.hex => intN
    # ex : 285257.to_hex => "045a49"
    # ex : 2.to_hex(8) => "00000002"
    # ex : 300.to_hex(1) => "012c"
    # Warning with negative number :
    # ex : -100.to_hex(1) => "-64"
    # ex : -100.to_hex(2) => "-0064"
    def to_hex(nb_byte=1)
      raise ArgumentError, "negative nb_byte" if nb_byte < 0
      return "-" + (-self).to_hex(nb_byte) if self < 0
      s = "%0#{nb_byte*2}x" % self
      s = (s.size.odd? ? '0' : '') + s
      s
    end

    def to_khash( precision=1 )
      (to_f / 10**3).round( precision )
    end

    def to_mhash( precision=1 )
      (to_f / 10**6).round( precision )
    end

    def to_ghash( precision=1 )
      (to_f / 10**9).round( precision )
    end
  end

  # refine String do
  class String
    # anHex.reverse_hex.reverse_hex => anHex +/- a leading 0
    # ex : "adbf986000000037".reverse_hex => "370000006098bfad"
    # ex : "-adbf986000000037".reverse_hex => "-370000006098bfad"
    def reverse_hex
      if self[0] == '-'
        '-' + ( self.size.even? ? self.insert(1,'0') : self ).scan(/\w{2}/).reverse.join
      else
        ( self.size.odd? ? '0'+self : self ).scan(/\w{2}/).reverse.join
      end
    end

    # ex : "adbf986000000037".to_bin => "\xAD\xBF\x98`\x00\x00\x007"
    def to_bin
      [self].pack("H*").force_encoding("ascii")
    end

    # ex : "\xAD\xBF\x98`\x00\x00\x007".to_hex => "adbf986000000037"
    def to_hex
      self.unpack("H*")[0]
    end

    # "1".hexsize => 1
    # "1f".hexsize => 1
    # "001f".hexsize => 2
    # "-1".hexsize => 1
    # "-1f".hexsize => 1
    # "-001f".hexsize => 2
    def hexsize
      ( ( self.size - ( self[0] == '-' ? 1 : 0 ) ) / 2.0 ).ceil
    end

    def hex?
      !! (self =~ /^-?[0-9a-f]+$/ || self =~ /^-?[0-9A-F]+$/)
    end

    def reverse_int_hex
      raise ArgumentError, "Hash must be 64 length" if self.size != 64
      self.scan(/\w{8}/).map { |h| h.reverse_hex }.join
    end

    def reverse_hash_int
      raise ArgumentError, "Hash must be 64 length" if self.size != 64
      self.scan(/\w{8}/).reverse.join
    end
  end

  # refine Array do
  class Array
    def to_h
      h = {}
      self.each_with_index do |v, i|
        raise TypeError, "wrong element type #{v.class} at #{i} (expected array)" unless v.kind_of?( Array )
        raise ArgumentError, "wrong array length at #{i} (expected 2, was #{v.size})" unless v.size == 2
        h[ v[0] ] = v[1]
      end
      h
    end
  end unless Array.instance_methods.include?( :to_h )

  # refine Hash do
  class Hash
    def compact
      self.select { |_,v| v }
    end
  end

  # refine OpenStruct do
  class OpenStruct
    def delete( field )
      self.delete_field( field ) rescue nil
    end
  end
# end

# module EventMachine
#   # Allows to safely run EM in foreground or in a background 
#   # regardless of is running already or not.
#   # 
#   # Foreground: EM::safe_run { ... }
#   # Background: EM::safe_run(:bg) { ... }
#   def EventMachine::safe_run(background = nil, &block)
#     if EventMachine::reactor_running?
#       # Attention: here we loose the ability to catch 
#       # immediate connection errors.
#       EventMachine::next_tick(&block)
#       sleep if $em_reactor_thread && !background
#     else
#       if background
#         $em_reactor_thread = Thread.new do
#           EventMachine::run(&block)
#         end
#         sleep( 0.01 ) while ! EventMachine::reactor_running?
#       else
#         EventMachine::run(&block)
#       end
#     end
#   end
# end
