# -*- encoding : utf-8 -*-

require 'eventmachine'
require 'json'
require 'loggable'
require 'listenable'

require_relative '../rpc'

# module Rpc::Handler
#
# Use it as a mixin.
#
# EventMachine API :
#   EM -> post_init ( call init_rpc_handler )
#   EM -> unbind ( call finalize_rpc_handler )
#   EM -> receive_data
#   EM <- send_data
# http://eventmachine.rubyforge.org/EventMachine/Connection.html
#
# Methods :
#   init_rpc_handler
#   send_notification( method, params )
#   send_notification( aRpcNotification )
#   send_request( method, params, id )
#   send_request( aRpcRequest )
#   send_response( result, id )
#   send_response( aRpcResponse )
#   send_error( aStandardError, id=nil )
#
# Signals :
#   Handler.emit( 'connect', aHandler )
#   Handler.emit( 'disconnect', aHandler )
#   emit( 'notification', notif )
#   emit( 'request', req )
#   emit( 'error', params )
#
#   # For debug purposes :
#   emit( 'data_received', data )
#   emit( 'line_received', line )
#   emit( 'json_received', json )
#   emit( 'response', resp )
#
module Rpc
  module Handler
    include Loggable
    include Listenable # for aHandler.emit and aHandler.on
    extend Listenable # for Handler.emit and Handler.on

    attr_reader :rip, :rport, :ip_port
    attr_accessor :skip_jsonrpc_field

    # 
    def post_init
      init_rpc_handler
    end

    def init_rpc_handler
      @skip_jsonrpc_field = true
      @response_waited = {} # ID => Callback
      @rport, @rip = Socket.unpack_sockaddr_in( get_peername ) if self.respond_to? :get_peername # From EventMachine::Connection
      @ip_port = "#{rip}:#{rport}"
      Handler.emit('connect', self)
    end

    # Register listener.
    def unbind
      finalize_rpc_handler
    end

    def finalize_rpc_handler
      Handler.log.debug "#{ip_port} disconnected"
      emit('disconnect')
      Handler.emit('disconnect', self)
    rescue => err
      puts "err in finalize_rpc_handler : #{err}"
      puts err.backtrace[0...5].join("\n")
    end

    ###############################################################################

    # when receive data, split them in lines
    def receive_data( data )
      emit( 'data_received', data )
      data.split("\n").map { |line|
        receive_line( line.strip )
      }
    end

    # when receive a line, try to parse it in JSON
    def receive_line( line )
      emit( 'line_received', line )
      json = JSON.parse(line)
      receive_json(json)
    rescue Rpc::Error => err
      send_error err
    rescue JSON::ParserError
      send_error Rpc::ParseError.new( line: line )
    rescue => err
      Handler.log.error "Connection::receive_data : #{err}\n>> line = '#{line}'\n" + err.backtrace.join("\n")
      send_error Rpc::InternalError.new( extra_msg: err.message, backtrace: err.backtrace[0..5] )
    end

    # When receive a valid json, verify it is a valid request
    # Raise or return it if valid
    def receive_json( json )
      emit( 'json_received', json )
      raise Rpc::InvalidRequest.new( extra_msg: "cmd is not a kind of Hash : #{json.class.name}" ) unless json.kind_of?( Hash )
      raise Rpc::InvalidRequest.new( id: json["id"], extra_msg: "cmd.jsonrpc is #{json["jsonrpc"].inspect} instead of #{Rpc::VERSION.inspect}" ) unless @skip_jsonrpc_field || json["jsonrpc"] == Rpc::VERSION
      if json["method"]
        raise Rpc::InvalidRequest.new( extra_msg: "cmd.id is not a kind of String or Number #{json["id"].class.name}" ) unless json["id"].nil? || json["id"].kind_of?( String ) || json["id"].kind_of?( Numeric )
        raise Rpc::InvalidRequest.new( id: json["id"], extra_msg: "cmd.method is not a kind of String #{json["method"].class.name}" ) unless json["method"].kind_of?( String )
        raise Rpc::InvalidRequest.new( id: json["id"], extra_msg: "cmd.params is not a kind of Array or Hash. #{json["params"].class.name}" ) unless json["params"].nil? || json["params"].kind_of?( Array ) || json["params"].kind_of?( Hash )
        json["id"] ? receive_request( json ) : receive_notification( json )
      elsif json["result"] != nil || ( json["error"] && json["id"] )
        raise Rpc::InvalidRequest.new( extra_msg: "cmd.id is not a kind of String or Number : #{json["id"].class.name}" ) unless json["id"].kind_of?( String ) || json["id"].kind_of?( Numeric )
        receive_response( json )
      elsif json["error"]
        emit( 'error', json )
      else
        raise Rpc::InvalidRequest.new( extra_msg: "Wait a 'method', a 'result' or an 'error' member." )
      end
    rescue => err
      Handler.log.error err
      raise
    end

    # When receive a valid request, call listeners
    # Return a Rpc::Notification
    def receive_notification( hNotif )
      method, params = hNotif["method"], hNotif["params"]
      Handler.log.debug "Notification received from #{ip_port}# : #{method} with #{params.inspect}"
      notif = Rpc::Notification.new(self, method, params)
      emit( 'notification', notif )
      notif
    end

    # When receive a valid request, call listeners
    # Return a Rpc::Request
    def receive_request( hReq )
      id, method, params = hReq["id"], hReq["method"], hReq["params"]
      Handler.log.debug "Request received from #{ip_port}##{id} : #{method} with #{params.inspect}"
      req = Rpc::Request.new(self, method, params, id)
      emit( 'request', req )
      req
    end

    # When receive a valid response, call handler
    # Return a Rpc::Response (or ErrorResponse)
    def receive_response hResp
      id, result, error = hResp["id"], hResp["result"], hResp["error"]
      Handler.log.debug "Response received from #{ip_port}##{id} : #{! result.nil? ? result : error}"
      if error
        resp = Rpc::ErrorResponse.new( error, id )
      else
        resp = Rpc::Response.new( result, id )
      end
      emit( 'response', resp )
      if @response_waited[id]
        @response_waited.delete(id).call(resp)
      else
        Handler.log.warn "No handler for this response !"
      end
    end

    ###############################################################################

    # send_notification(method, params, &block) => Rpc::Notification
    # send_notification(hash_notification, &block) => Rpc::Notification
    # send_notification(obj_notification, &block) => Rpc::Notification
    def send_notification *args, &block
      if args.length == 1 && args.first.kind_of?( Rpc::Notification )
        _send_request args.first
      elsif args.length == 1 && args.first.kind_of?( Hash )
        h = args.first
        send_notification( h["method"], h["params"], &block )
      elsif args.length == 2
        _send_request Rpc::Notification.new(self, *args)
      else
        raise Rpc::ServerError(-1, extra_msg: "in Rpc::Connection.send_notification : Wrong number of argument.", args: args)
      end
    end

    # send_request(method, params, id=nil, &block) => Rpc::Request
    # send_request(hash_request, &block) => Rpc::Request
    # send_request(obj_request, &block) => Rpc::Request
    def send_request *args, &block
      raise "A block MUST be given on send_request." unless block_given?
      if args.length == 1 && args.first.kind_of?( Rpc::Request )
        _send_request args.first, &block
      elsif args.length == 1 && args.first.kind_of?( Hash )
        h = args.first
        send_request( h["method"], h["params"], h["id"], &block )
      elsif args.length.between?(2, 3)
        _send_request Rpc::Request.new(self, *args), &block
      else
        raise Rpc::ServerError(-1, extra_msg: "in Rpc::Connection.send_request : Wrong number of argument.", args: args)
      end
    end

    # Return Rpc::Response
    def send_response *args
      if args.length == 1 && args.first.kind_of?( Rpc::Response )
        _send_response args.first
      elsif args.length == 1 && args.first.kind_of?( Rpc::ErrorResponse )
        _send_error args.first
      elsif args.length >= 1 && args.first.kind_of?(StandardError)
        send_error(*args)
      elsif args.length == 1 && args.first.kind_of?( Hash )
        h = args.first
        send_response( h["result"], h["id"] )
      elsif (1..2) === args.length
        _send_response Rpc::Response.new(*args)
      else
        raise Rpc::ServerError(-1, extra_msg: "in Rpc::Connection.send_response : Wrong number of argument.", args: args)
      end
    end

    # Return Rpc::ErrorResponse
    def send_error error, id=nil
      if error.kind_of?( Rpc::ErrorResponse )
        _send_error error
      elsif error.kind_of?( Rpc::Error )
        _send_error Rpc::ErrorResponse.new(error, id)
      else
        raise Rpc::ServerError.new(-1, extra_msg: "in Rpc::Connexion.send_error : Wrong type of argument : #{error.class} instead of Rpc::Error")
      end
    end

    private
      # request is an instance of Rpc::Request or Rpc::Notification
      # Return request
      def _send_request request, &block
        @response_waited[request.id] = block if block_given?
        send_data request
        request
      end

      # resp is an instance of Rpc::Response
      # Return Rpc::Response
      def _send_response resp
        Handler.log.debug "Sending result : #{resp}"
        send_data resp
        resp
      end

      # error_resp is an instance of Rpc::ErrorResponse
      # Return Rpc::ErrorResponse
      def _send_error error_resp
        Handler.log.debug "Sending error : #{error_resp}"
        send_data error_resp
        error_resp
      end

    # def puts_error err
    #   msg = "Error #{err["code"]} : #{err["message"]}.\n"
    #   backtrace = err["data"].delete("backtrace")
    #   err["data"].each do |key, value|
    #     msg += "- #{key} : #{value.inspect}\n"
    #   end
    #   msg += backtrace.join("\n")
    #   Handler.log.error msg
    # end
  end # module Connection
end # module Rpc
