ENV["RAILS_ENV"] ||= "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...

  # EventMachine utilities
  @@em_mutex = Mutex.new
  def get_em_mutex
    loop do
      sleep( 0.1 ) while EM.reactor_running?
      started = @@em_mutex.synchronize do
        next false if EM.reactor_running?
        Thread.new { EM.run }
        sleep( 0.1 ) while ! EM.reactor_running?
        true
      end
      break if started
    end
  end
end

# Disable logging
Loggable.mute

EM.error_handler do |err|
  puts "Error in EM: #{err}"
  puts err.backtrace.join("\n")
end

# Check if bitcoind -testnet is started
@testnet_ctrl = RpcController.new( "Bitcoin", "http://barbu:toto@localhost:18332", true )
raise "Bitcoin testnet not started" unless @testnet_ctrl.started?
raise "Bitcoin testnet not sync" unless @testnet_ctrl.sync?
