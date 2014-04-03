# -*- encoding : utf-8 -*-

class Chart
  AVAILABLE = []

  def self.inherited subclass
    Chart::AVAILABLE << subclass
  end

  # => Array of String
  def self.supported_currencies
    AVAILABLE.collect_concat(&:supported_currencies).uniq
  end

  # => Boolean
  def self.support? currency
    !! AVAILABLE.find { |chart| chart.support?( currency ) }
  end

  # => Float
  def self.get_difficulty currency
    AVAILABLE.each do |chart|
      next unless chart.support?( currency ) #&& chart.respond_to?( :get_difficulty )
      diff = chart.get_difficulty( currency ) rescue nil # Some strange StackLevelError
      puts "[WARNING] nil difficulty for currency=#{currency} on chart #{self.class.name}" if diff.nil?
      break diff if diff
    end
  end

  # => Float
  def self.get_reward currency
    AVAILABLE.each do |chart|
      next unless chart.support?( currency ) #&& chart.respond_to?( :get_reward )
      reward = chart.get_reward( currency ).to_f rescue nil
      puts "[WARNING] nil reward for currency=#{currency} on chart #{self.class.name}" if reward.nil?
      break reward if reward
    end
  end

  # def self.missing_method( name, *args, **hargs )
  #   AVAILABLE.each do |chart|
  #     next unless chart.support?( *args[0..1] ) && chart.respond_to?( :name )
  #     res = chart.name( *args, **hargs  ) rescue nil
  #     puts "[WARNING] nil delay for currency=#{args[0..1]} on chart #{self.class.name}" if res.nil?
  #     break res if res
  #   end
  # end

  # => Float
  def self.get_block_delay currency
    AVAILABLE.each do |chart|
      next unless chart.support?( currency ) #&& chart.respond_to?( :get_block_delay )
      delay = chart.get_block_delay( currency ) rescue nil # Some strange 
      puts "[WARNING] nil delay for currency=#{currency} on chart #{self.class.name}" if delay.nil?
      break delay if delay
    end
  end

end unless defined? Chart

# Load all charts files to make them available via Chart methods.
Dir["./charts/*.rb"].each {|file| require file }
