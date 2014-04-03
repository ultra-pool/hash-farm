# -*- encoding : utf-8 -*-

require_relative "./message"
require_relative './response'

module Rpc
  class Request < Rpc::Message
    @@id_ctr = 1

    attr_reader :id

    def initialize handler, method, params=[], id=nil
      super(handler, method, params)
      @id = id || (@@id_ctr += 1)
      @is_responded = false
    end

    def valid?
      super && @id.kind_of?( Integer )
    end

    def responded?
      @is_responded
    end

    def to_h
      super.merge( "id" => id )
    end

    def response=( resp )
      raise "Response must be a Rpc::Response, not a #{resp.class}." if ! resp.kind_of?( Rpc::Response )
      raise "Response has already been sent !" if @is_responded
      @response = resp
    end

    def send_response
      raise "Response has already been sent !" if @is_responded
      raise "No response has been set !" if @response.nil?
      @is_responded = true
      handler.send_response @response
    end

    def respond result
      self.response = Rpc::Response.factory(result, @id)
      self.send_response
    end

    def error error
      self.response = Rpc::ErrorResponse.new(error, @id)
      self.send_response
    end
  end # class Request
end # module Rpc
