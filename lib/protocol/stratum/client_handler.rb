# -*- encoding : utf-8 -*-

require "core_extensions"
require 'listenable'

module Stratum
  class ClientHandler
    include Listenable

    def initialize( handler )
      @handler = handler
    end

    # Verify that request has good parameters
    # Return true or raise the error
    def validate_request req
      id = req.id if req.respond_to? :id
      method, params = req.method.sub(/^client\./,''), req.params

      # case method
      # else
      raise Rpc::MethodNotFound.new( id: id, method: "client.#{method}" )
      # end

      emit( method, req )
      true
    rescue => err
      emit( 'error', err, req )
      raise
    end

    def reconnect *args
      host, port, wait = *args
      return @handler.close_connection if host.nil?
      # port, host = *Socket.unpack_sockaddr_in( @handler.get_sockname ) if host.nil?
      @handler.send_notification( 'client.reconnect', [host, port, wait || 0] )
    rescue => err
      puts err, err.backtrace[0...5].join("\n")
    end
  end
end
