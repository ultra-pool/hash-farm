# -*- encoding : utf-8 -*-

require_relative '../stratum'

require_relative './mining_handler'
require_relative './block_handler'
require_relative './client_handler'

#
# module Stratum::Handler
#
# Use it as a mixin.
#
# EventMachine API :
#   EM -> post_init ( call init_stratum_handler )
#   EM -> unbind ( call finalize_stratum_handler )
#
# Attributs :
#   mining
#   block
# Methods : see mining and block methods.
# Signals :
#   emit( 'mining.subscribe', req )
#   emit( 'mining.unsubscribe', req )
#   emit( 'mining.authorize', req )
#   emit( 'mining.submit', req )
#   emit( 'mining.notify', req )
#   emit( 'mining.set_difficulty', req )
#   also see mining and block signals.
#
module Stratum
  module Handler
    include Rpc::Handler
    extend Listenable # for Handler.emit and Handler.on

    # 
    def post_init
      init_stratum_handler
    end

    attr_reader :mining, :block, :client

    def init_stratum_handler
      init_rpc_handler
      @skip_jsonrpc_field = true

      # init stratum modules.
      @mining = Stratum::MiningHandler.new(self)
      @block = Stratum::BlockHandler.new(self)
      @client = Stratum::ClientHandler.new(self)
      
      # Register listener.
      on( 'request' ) do |req|
        validate_request( req )
      end
      on( 'notification' ) do |notif|
        validate_request( notif )
      end
      mining.on( 'error' ) do |*params|
        emit( 'mining.error', *params )
        emit( 'error', *params )
      end
      block.on( 'error' ) do |*params|
        emit( 'block.error', *params )
        emit( 'error', *params )
      end
      Handler.emit('connect', self)
    end

    def unbind
      finalize_rpc_handler
      finalize_stratum_handler
    rescue => err
      puts "err in unbind : #{err}"
    end

    def finalize_stratum_handler
      Handler.emit('disconnect', self)
    rescue => err
      puts "err in finalize_stratum_handler : #{err}"
    end

    def validate_request req
      case req.method
      when /^mining./
        mining.validate_request req
      when /^block./
        block.validate_request req
      else
        raise Rpc::MethodNotFound.new( id: req.id, method: req.method )
      end
      emit( req.method, req )
    end
  end
end
