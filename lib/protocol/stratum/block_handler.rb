# -*- encoding : utf-8 -*-

require 'listenable'

#
# class Stratum::Block
#
# A member of Stratum::Handler.
# Allow aHandler.block.do_something, aHandler.block.on(signal), etc
# instead of aHandler.block_do_something or aHander.on("block_signal").
#
# Methods :
#   notify
# Signals :
#   emit( 'notify', req )
#
module Stratum
  class BlockHandler
    include Listenable

    def initialize( handler )
      @handler = handler
    end

    # Verify that request has good parameters
    # Return true or raise the error
    def validate_request req
      id, method, params = req.id, req.method.sub(/^block\./,''), req.params

      case method
      when "notify"
        coin_code, password, hash = *params
        raise Rpc::InvalidParams.new( extra_msg: "coin_code is invalid : #{coin_code}" ) if ! coin_code =~ /^\w{3,5}$/
      else
        raise JSON_RPC::MethodNotFound.new( method: "block.#{method}" )
      end

      emit( method, req )

      true
    end

    def notify( *args )
      self.send_notification 'block.notify', *args
    end
  end # module Block
end # module Stratum
