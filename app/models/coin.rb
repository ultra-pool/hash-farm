# -*- encoding : utf-8 -*-

# require "loggable"
require "rpc_controller"

# TODO: Missing field : addr_prefix and starting_reward
class Coin < ActiveRecord::Base
  # include Loggable

  has_many :accounts

  def validate_rpc_url
    # aucune url ne doit avoir le même host:port
    raise "Invalid url" if rpc_url =~ /@([^:]):(\d+)\Z/
    host, port = $~[1], $~[2]
    Coin.where(["rpc_url LIKE '?:?'", host, port])
    # Gestion du localhost <=> 127.0.0.1
    # Idem du localhost <=> 0.0.0.0
    # Idem du localhost <=> 192.168.0.X
  end

  def self.[]( code )
    find_by_code( code )
  end

  def rpc
    @rpc ||= RpcController.new( self.name, self.rpc_url, Rails.env.test? ) # Define in test_helper
  end

  def height
    rpc.getinfo["blocks"]
  end

  def reward( block_number )
    return self.starting_reward / (2 ** ((height + 1) / self.difficulty_retarget).to_i)
  end

  def start_deamon
    rpc.launch_deamon
  end

  def stop_deamon
    rpc.stop_deamon
  end

  def restart_deamon
    rpc.restart_deamon
  end

  def account_for( addr )
    rpc.getaccount( addr )
  end
  def accounts
    rpc.listaccounts.keys
  end
  def addresses( account )
    rpc.getaddressesbyaccount( account )
  end
  def balance( addr=nil )
    raise
  end

  def testnet_rpc
    if self.rpc_url =~ /:(\d+)$/
      url = self.rpc_url.gsub( $~[1], ($~[1].to_i + 10000).to_s )
    else
      raise "Cannot start testnet, unable to match port"
    end
    @testnet_rpc ||= RpcController.new( self.name, url, true ) # Define in test_helper
  end

  def testnet_start_deamon
    testnet_rpc.start_deamon
  end

  def testnet_stop_deamon
    testnet_rpc.stop_deamon
  end
end
