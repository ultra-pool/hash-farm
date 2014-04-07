# -*- encoding : utf-8 -*-

require 'open-uri'
require 'socket'
require 'json'
require 'eventmachine'
require "io/wait"

require 'loggable'
require_relative '../stratum'

=begin
# Usage :

client = Stratum::Client.new 'otherpool.com', 3333

client.on_request do |req|
  puts "Receive #{req["id"] ? "request" : "notification"} #{req["method"]} with param=#{req["params"]}"
end

client.on('connected') do
  client.subscribe do |resp|
    subs, extra1, extra2_size = resp["result"]
    subscriptions = Hash[ *subs ]
    puts "Subscribe to #{subscriptions.keys}"
    puts "with ids #{subscriptions.values}"
  end

  client.authorize() do |resp|
    puts resp["result"] ? "Connection authorized." : "Connection FORBIDDEN !"
  end
end

client.on_mining_notify do |params|
  puts "New notification : #{params}"
end

client.on_set_difficulty do |params|
  puts "New difficulty is #{params.first}"
end

client.connect

sleep(5)

client.submit("slush.miner1", "job_id", "00000001", "504e86ed", "b2957c02") do |resp|

end
=end

module Stratum
  class Client
    include Loggable
    include Stratum::Handler.dup

    DEFAULT_READ_SOCKET_INTERVAL = Rails.env.test? ? 0.01 : 0.2
    
    attr_reader :host, :port
    attr_reader :last_difficulty, :last_notification
    attr_accessor :read_socket_interval

    def initialize( host, port, options={} )
      @host, @port, @options = host, port, options
      @fibo_a, @fibo_b = 1, 1
      
      @read_socket_interval = DEFAULT_READ_SOCKET_INTERVAL

      on( 'mining.set_difficulty' ) do |notif|
        @last_difficulty = notif.params.first
        log.verbose "Difficulty is now #{@last_difficulty}."
      end
      on( 'mining.notify' ) do |notif|
        @last_notification = notif.params
        log.verbose "Job #{@last_notification.first.inspect} received."
      end
    end

    def connect( host=@host, port=@port )
      log.verbose "Connecting to #{host}:#{port}..."
      @socket = TCPSocket.new( host, port )
      _, @rport, _, @rip = @socket.peeraddr
      post_init() # Stratum::Handler

      raise "EventMachine must be running." if ! EM.reactor_running?
      @timer.cancel if @timer
      @timer = EM.add_periodic_timer( @read_socket_interval ) do
        data = ""
        data += @socket.read_nonblock( 4096 ) while @socket.ready?
        receive_data( data ) unless data.empty?
      end

      emit('connected')
    rescue => err
      # Save previous url
      phost, pport = host, port
      
      # Get backup url
      if @options[:back].nil?
        raise
      elsif @options[:back].kind_of?( URI )
        uri = @options[:back]
        host, port = uri.host, uri.port
      elsif @options[:back].kind_of?( String )
        uri = URI( @options[:back] )
        host, port = uri.host, uri.port
      elsif @options[:back].kind_of?( Array )
        host, port = *@options[:back]
      end
      # Reraise if we were already on backup
      raise if phost == host && pport == port
      
      # Try to connect with backup
      log.warn "Fail to start @#{phost}:#{pport}. Try on backup@#{host}:#{port}.. (#{err})"
      connect( host, port )
      
      # If fail retry every x second, fibonacci increment
      if @socket.nil?
        @fibo_a, @fibo_b = @fibo_a + @fibo_b, @fibo_a
        EM.add_timer( @fibo_a ) do connect() end
      end
    end

    def send_data data
      @socket.write_nonblock( data )
    rescue IO::WaitWritable, Errno::EINTR
      log.info "Fail to send data. Retry in background... (#{data[0...80]}...)"
      # Retry in background
      Thread.new(data) do |data|
        IO.select(nil, [@socket])
        @socket.write( data )
        log.info "Data sent (#{data[0...80]})."
      end
    rescue Errno::EPIPE, Errno::ECONNRESET
      log.warn "Connection lost to #{ip_port}. Retry..."
      self.connect
      mining.on('subscribed') do self.send_data data end
    rescue => err
      log.error "Error during send_data to #{ip_port} : #{err}. Retry...\n#{err.backtrace[0]}"
      count ||= 0
      count += 1
      sleep(0.1)
      retry if count < 3
    end

    def close
      @timer.cancel if @timer
      @socket.close if @socket
      unbind()
    end

    def closed?
      @socket.closed?
    end

    def inspect
      to_s
    end
    def to_s
      "#Client@%s:%d" % [host, port]
    end
  end # class Client
end # module Stratum
