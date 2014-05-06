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
  puts "Receive request##{req.id} #{req.method} with param=#{req.params}"
end

client.on('connected') do
  client.subscribe do |resp|
    subs, extra1, extra2_size = resp.result
    subscriptions = Hash[ *subs ]
    puts "Subscribe to #{subscriptions.keys}"
    puts "with ids #{subscriptions.values}"
  end

  client.authorize("toto", "foo") do |resp|
    puts resp.result ? "Connection authorized." : "Connection FORBIDDEN !"
  end
end

client.mining.on('notify') do |params|
  puts "New notification : #{params}"
end

client.mining.on('set_difficulty') do |params|
  puts "New difficulty is #{params.first}"
end

client.connect

sleep(5)

client.submit("slush.miner1", "job_id", "00000001", "504e86ed", "b2957c02") do |resp|

end
=end

module Stratum
  # The Client create a TCP connection to a stratum server,
  # and emit signals when request and notification arrive.
  #
  # See Stratum::Handler for more informations.
  #
  # Signals :
  # - connected
  # - disconnected
  # - reconnected
  # Warning: Stratum::Handler has signals connect/disconnect.
  #
  # Methods :
  # - connect
  # - close
  class Client
    include Loggable
    include Listenable
    include Stratum::Handler.dup

    DEFAULT_READ_SOCKET_INTERVAL = Rails.env.test? ? 0.01 : 0.2
    
    attr_reader :host, :port
    attr_accessor :read_socket_interval

    def initialize( host, port, options={} )
      @host, @port = host, port
      @back_uri = options[:back] && URI(options[:back])
      @read_socket_interval = DEFAULT_READ_SOCKET_INTERVAL
    end

    def connect
      _connect( @host, @port )
      post_init() # Stratum::Handler
      _start_timer
      emit('connected')
    end

    def close
      _stop_timer
      _disconnect
      unbind()
      emit('disconnected')
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

    def reconnect
      log.warn "Connection lost to #{ip_port}. Try to reconnect..."
      _disconnect
      _connect
      emit('reconnected')
    rescue => err
      log.err "Fail to reconnect : #{err}\n" + err.backtrace[0..3].join("\n")
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
      log_msg = "waiting socket.write..."
      if IO.select(nil, [@socket], nil, 0.5)
        log_msg = "writing..."
        @socket.write( data )
      else
        log_msg "#{ip_port} not available"
        raise
      end
    rescue Errno::EPIPE, Errno::ECONNRESET, Errno::EINTR, Timeout::Error
      log.error "Lost connection on writing... (#{log_msg})"
      self.reconnect
      log.error "Share lost : #{data}" if data =~ /submit/
    rescue => err
      log.error "Error during send_data to #{ip_port} : #{err} (#{log_msg}). Retry...\n#{err.backtrace[0]}"
      count ||= 0
      count += 1
      sleep(0.1)
      retry if count < 3
      self.reconnect
    end

    def _connect( host, port )
      log.info "[#{host}:#{port}] Connecting..."
      @socket = TCPSocket.new( host, port )
      _, @rport, _, @rip = @socket.peeraddr
      log.info "[#{host}:#{port}] Connected."
    rescue => err
      log.error "Fail to connect to #{@host}:#{@port} : #{err}\n" + err.backtrace[0...5].join("\n")
      # Reraise if we were already on backup or if there is no backup.
      raise if host != @host || port != @port || @back_uri.nil?
      
      # Try to connect with backup
      log.warn "Fail to connect @#{host}:#{port}. Try on backup@#{back_uri.host}:#{back_uri.port}.. (#{err})"
      _connect( back_uri.host, back_uri.port )
    end

    def _disconnect
      log.info "Disconnecting..."
      @socket.close if @socket
      @socket = nil
      log.info "Disconnected."
    end

    def _start_timer
      raise "EventMachine must be running." if ! EM.reactor_running?
      @timer = EM.add_periodic_timer( @read_socket_interval ) do
        begin
          data = read_data
          receive_data( data ) unless data.nil? || data.empty?
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
