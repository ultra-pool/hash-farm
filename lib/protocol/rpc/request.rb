# -*- encoding : utf-8 -*-

require_relative './notification'
require_relative './response'

module Rpc
  class Request < Notification
    @@id_ctr = 1

    attr_reader :id

    def initialize handler, method, params=[], id=nil
      super(handler, method, params)
      @id = id || (@@id_ctr += 1)
    end

    def request?
      true
    end

    def notification?
      false
    end

    def valid?
      super && id.kind_of?( Integer )
    end

    def responded?
      !! @is_responded
    end

    def to_h
      super.merge( "id" => id )
    end

    def response_with result
      Rpc::Response.new(result, @id)
    end

    def response_with_error error
      Rpc::ErrorResponse.new(error, @id)
    end

    def respond result
      @is_responded = true
      resp = response_with result
      handler.send_response resp
    end

    def error error
      resp = response_with_error error
      handler.send_error resp
    end
  end # class Request
end # module Rpc
