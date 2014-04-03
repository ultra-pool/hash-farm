# -*- encoding : utf-8 -*-

require 'net/http'
require 'open-uri'
require 'json'

require './lib/loggable'

# See https://en.bitcoin.it/wiki/Original_Bitcoin_client/API_Calls_list
# or https://litecoin.info/Litecoin_API
# for a list of all possible commands
class RpcController
  include Loggable

  BLOCK_NOTIFY_SCRIPT_PATH = Rails.root + "/script/block_notify.rb"

  attr_reader :name, :uri, :deamon_thread
  attr_accessor :prog

  def initialize( coin_name, rpc_url, testnet=false )
    @coin_name, @uri = coin_name, URI( rpc_url )
    @prog = "#{coin_name.downcase}d"
    @prog += " -testnet" if testnet
    # @log = Loggers.get_logger( __FILE__ )
  end

  def started?
    !! ( @deamon_thread || self.getinfo )
  rescue
    false
  end

  def sync?
    height = self.getblockcount
    hash = self.getblockhash( height )
    block = self.getblock( hash )
    time = Time.at( block["time"] )
    time > Time.now - (60*90) # 90 min
  end

  def listunspent( *args )
    miniconf, maxconf = 1, 999999
    miniconf = args.shift if args.first.kind_of?( Integer )
    maxconf = args.shift if args.first.kind_of?( Integer )
    raise ArgumentError, "Cannot get addresses from #{args}" if ! args.all? { |arg| arg.kind_of?( String ) }
    addresses = args
    method_missing( :listunspent, miniconf, maxconf ).select! do |tx|
      addresses.include?( tx["address"] ) || addresses.include?( tx["account"] )
    end
  end

  def start_deamon(host=nil, port=nil, *args)
    return if started?
    @deamon_thread = Thread.new do
      command = '%s --rpcuser="%s" --rpcpassword="%s" --rpcport=%s' % [@prog, @uri.user, @uri.password, @uri.port]
      command += ' -blocknotify="%s %s:%s %s %%s"' % [BLOCK_NOTIFY_SCRIPT_PATH, host, port, args.join(' ')] if host && port
      log.info( "#{@prog} start on port #{@uri.port}." )
      `#{command}`
    end
    sleep(1)
  end

  def stop_deamon
    return unless started?
    stop
    if @deamon_thread
      @deamon_thread.join
      @deamon_thread = nil
    else
      sleep(2)
    end
    log.info( "#{@prog} stopped." )
    self
  end

  def restart_deamon
    stop_deamon
    start_deamon
  end

  def method_missing(name,  *args)
    post_body = { 'method' => name, 'params' => args, 'id' => 'jsonrpc' }.to_json
    resp = JSON.parse( http_post_request(post_body) )
    raise "for `#{name}' : " + resp['error'].inspect if resp['error']
    resp['result']
  end

  def http_post_request(post_body)
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.content_length = post_body.size
    request.body = post_body
    http.request(request).body
  end
end
