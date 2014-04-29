# -*- encoding : utf-8 -*-

require 'socket'
require 'json'
require 'eventmachine'

require_relative '../stratum'

=begin

class Stratum::Server

Attributs :
  host, port
  block
Methods :
  start
  start_with_reactor
  stop

Signals :
  emit( 'start' )
  emit( 'connect', cnx, params )
  emit( 'disconnect', cxn )
  emit( 'notification', cxn, notif )
  emit( 'request', cxn, req )
  emit( 'stop' )

# Usage :

server = Stratum::Server.new( "0.0.0.0", 3333 )

server.on( 'connect' ) do |cxn|
  puts "Connexion received from #{cxn.ip_port}"
end

server.on( 'request' ) do |cnx, req|
  puts "Miner from #{cnx.ip_port} send request #{req.method}"
end

server.on( 'mining.subscribe' ) do |cnx, req|
  puts "Miner from #{cxn.ip_port} has subscribed"
  req.respond [[["mining.set_difficulty", "b4b6693b72a50c7116db18d6497cac52"], ["mining.notify", "ae6812eb4cd7735a302a8a9dd95cf71f"]], "08000002", 4]
end

server.on( 'mining.authorize' ) do |cnx, req|
  puts "Miner from #{req.cxn.ip_port} ask authorization for #{req.params.inspect}"
  req.respond true
end

server.start_with_reactor # Blocking until server is closed by Ctrl+C, SIGINT or SIGTERM

=end
module Stratum
  class ServerHandler < EM::Connection
    include Stratum::Handler
  end

  # def log( *args )
  #   Server.log( *args )
  # end

  class Server
    include Loggable
    include Listenable

    SIGNALS = ["start", "connect", "disconnect", "notification", "request", "stop"]

    attr_reader :host, :port
    attr_reader :handler

    def initialize( host, port )
      @host, @port = host, port
      @handler = ServerHandler.dup
      @server_signature = nil
      @started = false
    end

    def init_event_machine
      Thread.new do EM.run end unless EM.reactor_running?
      EM.error_handler do |error|
        log.error "EventMachine: #{error}" + error.backtrace[0...2].join("\n")
        emit( 'error', 'eventmachine', error )
      end
      sleep( 0.05 ) while ! EM.reactor_running?
    end

    def handler=( handler )
      raise if started?
      @handler = handler
    end

    def started?
      @started &&= EM.reactor_running?
    end

    # Lunch EM reactor and start server in this context.
    def start_with_reactor
      EventMachine.error_handler do |err|
        puts "Error in EM: #{err}"
        puts err.backtrace.join("\n")
      end
      EventMachine.run do
        self.start
      end
    end


    # EM reactor MUST be started.
    # Look at Server.start_reactor.
    def start
      init_event_machine unless EM.reactor_running?
      EM.next_tick do
        @server_signature = EventMachine.start_server( host, port, @handler )
        Server.log.info "Started Stratum::Server on #{host}:#{port}..."
        @started = true
        emit( 'start' )
      end

      Stratum::Handler.on( 'connect' ) do |cxn|
        next unless cxn.kind_of?( @handler )
        emit('connect', cxn)
        cxn.on( 'error' ) do |*err| emit( 'error', cxn, *err) end
        cxn.on( 'notification' ) do |notif| emit( 'notification', cxn, notif) end
        cxn.on( 'request' ) do |req| emit( 'request', cxn, req) end
      end
      Stratum::Handler.on( 'disconnect' ) do |cxn|
        next unless cxn.kind_of?( @handler )
        emit('disconnect', cxn)
        cxn.off(self)
      end
      self
    end

    def restart
      stop
      start
    end

    def stop
      EventMachine.stop_server( @server_signature ) rescue nil
      @started = false
      # Server.log.info "Stratum::Server on #{host}:#{port} stopped." # can't be called from trap context (ThreadError)
      Stratum::Handler.off(self, 'connect')
      # ObjectSpace.each_object(@handler) do |cxn| cxn.close end
      Stratum::Handler.off(self, 'disconnect')
      emit( 'stop' )
      self
    end

    alias_method :on_event, :on
    def on( signal, *args, &block )
      if SIGNALS.include?( signal )
        on_event( signal, *args, &block )
      else
        self.on( 'connect' ) do |cxn|
          cxn.on( signal ) do |*params|
            listener_callback(*args, &block).call(cxn, *params)
          end
        end
      end
    end
  end
end
