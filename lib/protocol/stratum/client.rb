# -*- encoding : utf-8 -*-

require 'open-uri'
require 'socket'
require 'eventmachine'
require "io/wait" # For @socket.ready?

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
    include Listenable
    include Stratum::Handler.dup

    DEFAULT_READ_SOCKET_INTERVAL = Rails.env.test? ? 0.01 : 0.2
    
    attr_reader :host, :port
    attr_accessor :read_socket_interval

    # For debug purpose
    attr_reader :last_difficulty, :last_notification

    def initialize( host, port, options={} )
      @host, @port = host, port
      @back_uri = options[:back] && URI(options[:back])
      
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

    def connect
      _connect( @host, @port )
      post_init() # Stratum::Handler
      _start_timer
      emit('connected')
    end

    def reconnect
      log.warn "Connection lost to #{ip_port}. Try to reconnect..."
      _disconnect
      _connect
      emit('reconnected')
    end

    def read_data
      data = ""
      data += @socket.read_nonblock( 4096 ) while @socket.ready?
      data
    rescue Errno::EPIPE, Errno::ECONNRESET, Errno::EINTR
      log.error "Lost connection on reading..."
      self.reconnect
      ""
    rescue => err
      log.error "while reading : #{err}\n" + err.backtrace[0...5].join("\n")
      self.reconnect
      ""
    end

    def send_data data
      print '- '; $stdout.flush
      if IO.select(nil, [@socket], nil, 0.5)
        print "write..."; $stdout.flush
        @socket.write( data )
        puts "ed"
      else
        puts "#{ip_port} not available"
        raise
      end
    rescue Errno::EPIPE, Errno::ECONNRESET, Errno::EINTR, Timeout::Error
      log.error "Lost connection on writing..."
      self.reconnect
      log.error "Share lost : #{data}" if data =~ /submit/
    rescue => err
      log.error "Error during send_data to #{ip_port} : #{err}. Retry...\n#{err.backtrace[0]}"
      count ||= 0
      count += 1
      sleep(0.1)
      retry if count < 3
      self.reconnect
    end

    def close
      _stop_timer
      _disconnect
      unbind()
    end

    def closed?
      @socket.nil? || @socket.closed?
    end

    def inspect
      to_s
    end
    def to_s
      "#Client@%s:%d" % [host, port]
    end

    # private

    def _connect( host, port )
      log.verbose "Connecting to #{host}:#{port}..."
      @socket = TCPSocket.new( host, port )
      _, @rport, _, @rip = @socket.peeraddr
    rescue => err
      log.error err, err.backtrace[0...5].join("\n")
      # Reraise if we were already on backup or if there is no backup.
      raise if host != @host || port != @port || @back_uri.nil?
      
      # Try to connect with backup
      log.warn "Fail to connect @#{@host}:#{@port}. Try on backup@#{back_uri.host}:#{back_uri.port}.. (#{err})"
      _connect( back_uri.host, back_uri.port )
    end

    def _disconnect
      log.verbose "Disconnecting..."
      @socket.close if @socket
      @socket = nil
    end

    def _start_timer
      raise "EventMachine must be running." if ! EM.reactor_running?
      @timer = EM.add_periodic_timer( @read_socket_interval ) do
        begin
          data = read_data
          receive_data( data ) unless data.empty?
        rescue => err
          log.error "in read timer : #{err}\n" + err.backtrace[0..5].join("\n")
        end
      end
    end

    def _stop_timer
      @timer.cancel if @timer
      @timer = nil
    end
  end # class Client
end # module Stratum
