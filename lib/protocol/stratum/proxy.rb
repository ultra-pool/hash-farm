# -*- encoding : utf-8 -*-

require 'socket'
require 'json'
require 'eventmachine'

require_relative './server'

=begin

proxy = Stratum::Proxy.new "0.0.0.0", 9148, "otherpool.com", 3333

EM.run do
  proxy.start # block until server is closed by Ctrl+C, SIGINT or SIGTERM
end

puts "Proxy closed."

=end
module Stratum
  class Proxy < Stratum::Server
    include Loggable

    attr_reader :our_host, :our_port, :pool_host, :pool_port
    attr_reader :clients

    def initialize( our_host, our_port, pool_host, pool_port )
      super( our_host, our_port )
      @pool_host, @pool_port = pool_host, pool_port
      @clients = {}

      on( 'connect' ) do |cxn|
        log.info "cxn received from #{cxn.ip_port}"
        log.debug "Create cxn to #{@pool_host}"
        client = Stratum::Client.new( @pool_host, @pool_port )
        @clients[cxn.ip_port] = client

        # On branche les requests du miner vers la pool
        cxn.on( 'request' ) do |req|
          log.verbose "Request received from #{cxn.ip_port} : #{req.method}##{req.id}"
          log.debug req.params.inspect
          client.send_request( req ) do |resp|
            # On renvoie la réponse de la pool vers le miner
            log.verbose "Response received from #{client.ip_port} : ##{resp.id}"
            log.debug resp.result.inspect
            cxn.send_response resp
          end
        end
        cxn.on( 'disconnect' ) do
          emit( 'cxn_in.disconnect', cxn )
          cxn.off(self)
          client.close if @clients.delete( cxn.ip_port )
        end

        # On branche les notifications de la pool vers le miner
        client.on( 'notification' ) do |notif|
          log.verbose "Notification received from #{client.ip_port} : #{notif.method}"
          log.debug notif.params.inspect
          cxn.send_notification notif
          emit( 'notification', client, notif )
        end

        # On branche les requests de la pool vers le miner
        client.on( 'request' ) do |req|
          log.warn "Request received from #{client.ip_port}##{req.id} : #{req.method} !!"
          log.debug req.params.inspect
          cxn.send_request req do |resp|
            # On renvoie la réponse du miner vers la pool
            log.verbose "Response received from #{cxn.ip_port} : ##{resp.id}"
            log.debug resp.result.inspect
            client.send_response resp
          end
          emit( 'request', client, notif )
        end
        client.on( 'disconnect' ) do
          log.verbose "#{cxn.ip_port} disconnect."
          emit( 'cxn_out.disconnect', client )
          client.off(self)
          cxn.close if @clients.delete( cxn.ip_port )
        end

        client.connect
      end
    end

    def start
      super
    end

    def stop
      super
      client = @clients.shift[1].close while ! @clients.empty?
    end
  end # class Proxy
end # module Stratum
