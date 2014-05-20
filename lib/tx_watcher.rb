#!/usr/bin/ruby

require 'bitcoin/connection'
require 'protocol/rpc/handler'
require 'core_extensions'
require 'mining_helper'

Bitcoin::network = :bitcoin

# Server on which client will connect to ask for watching addresses.
#
# Listen for requests (methods / params -> resp):
# - address.watch / [address, ...] -> true/false
# - address.unwatch / [address, ...] -> true/false
# - authentify / [login, mdp] -> true/false
# - address.list / [] -> liste des adresses watchées.
#
# Send notifications when addresses are recognize :
# - address.new_tx / [txid, vout, address, amount]
#
module ClientHandler
  include Rpc::Handler
  include Loggable

  attr_reader :addresses

  def post_init
    super
    ClientHandler.log.info "[#{ip_port}] New connection"
    @addresses = []
    self.on( 'request' ) do |req| on_request( req ) end
    self.on( 'notification' ) do |notif|
      ClientHandler.log.warn "[ClientHandler][#{ip_port}] Notification recieved : #{notif}"
    end
  end

  def on_request( req )
    case req.method
    when 'address.watch'
      
      res = req.params.map { |addr|
        next false if ! MiningHelper.coin_addr_type?( addr )
        @addresses << addr
        ClientHandler.log.info "[#{ip_port}] Watch #{addr}"
        emit( 'address.watch', addr )
        true
      }.all?
      req.respond( res )
    when 'address.unwatch'
      res = req.params.map { |addr|
        next false if ! MiningHelper.coin_addr_type?( addr )
        addr = @addresses.delete( addr )
        ClientHandler.log.info "[#{ip_port}] Unwatch #{addr}"
        emit( 'address.unwatch', addr ) if addr
        !! addr
      }.all?
      req.respond( res )
    when 'address.list'
      ClientHandler.log.verbose "[#{ip_port}] Ask for addresses list : #{@addresses.size} addresses"
      req.respond @addresses
    else
      req.error Rpc::MethodNotFound.new
    end
  end

  def send_new_tx( txid, vout, address, amount )
    ClientHandler.log.info "[#{ip_port}] New tx #{address} += #{amount.to_mbtc(1)} mBTC @#{txid}:#{vout}"
    send_notification method: "address.new_tx", params: [txid, vout, address, amount]
  end
end

class Watcher < Bitcoin::Connection
  include Loggable

  def self.run

    Signal.trap("INT") do
      puts "\033[31m 'INT' signal received. Going to shutdown Watcher......\033[0m"
      EM.add_timer(0) { EM.stop_server( @@client_server ); @@watcher_client.stop }
      EM.add_timer(1) { EM.stop }
    end

    EM.run do
      @@client_server = EM.start_server( "0.0.0.0", 6644, ClientHandler )

      # host = '127.0.0.1'
      #host = '217.157.1.202'
      #Connection.connect(host, 8333)
      @@watcher_client = Watcher.connect_random_from_dns([])
    end
  end

  def self.connect_random_from_dns(connections)
    seeds = Bitcoin.network[:dns_seeds]
    if seeds.any?
      host = `nslookup #{seeds.sample}`.scan(/Address\: (.+)$/).flatten.sample
      if host.blank?
        self.connect_random_from_dns(connections)
      else
        connect(host, Bitcoin::network[:default_port], connections)
      end
    else
      raise "No DNS seeds available. Provide IP, configure seeds, or use different network."
    end
  end

  def initialize(host, port, connections)
    super
    @parser.instance_variable_set(:@log, Watcher.log)
    @addresses = {}

    Rpc::Handler.on( 'connect' ) do |c|
      c.on( 'address.watch' ) do |addr|
        @addresses[addr] ||= []
        @addresses[addr] << c
      end
      c.on( 'address.unwatch' ) do |addr|
        @addresses[addr].delete( c )
        @addresses.delete(addr) if @addresses[addr].empty?
      end
    end
    Rpc::Handler.on( 'disconnect' ) do |c|
      c.addresses.each do |addr|
        @addresses[addr].delete( c )
        @addresses.delete(addr) if @addresses[addr].empty?
      end
    end
  end

  ###############################

  def post_init
    log.info "#{@sockaddr} connected"
    EM.schedule{ on_handshake_begin }
  end

  def unbind
    log.info "#{@sockaddr} disconnected" unless @stopped
    self.class.connect_random_from_dns( @connections ) unless @stopped
  rescue
    self.class.connect_random_from_dns( @connections ) unless @stopped
  end

  def stop
    @stopped = true
    close_connection
  end

  ###############################

  def on_tx(tx)
    log.verbose "#{tx.hash} received"
    tx.out.each_with_index { |out, vout|
      addr = Bitcoin::Script.new(out.pk_script).get_address
      next unless @addresses[addr].present?
      txid, amount = tx.hash, out.value
      @addresses[addr].each do |c| c.send_new_tx( txid, vout, addr, amount ) end
    }
  end

  def on_inv_transaction(hash)
    pkt = Bitcoin::Protocol.getdata_pkt(:tx, [hash])
    send_data(pkt)
  end
  def on_inv_block(hash)
    pkt = Bitcoin::Protocol.getdata_pkt(:block, [hash])
    send_data(pkt)
  end
  def on_get_transaction(hash)
  end
  def on_get_block(hash)
  end
  def on_addr(addr)
  end
  def on_block(block)
  end
end
