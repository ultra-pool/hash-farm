# -*- encoding : utf-8 -*-

module Rpc
  class Message
    attr_reader :handler, :method, :params

    def initialize handler, method, params=[]
      @handler, @method, @params = handler, method, params
    end

    def valide?
      method.kind_of?( String ) &&
      ( params.nil? || params.kind_of?( Enumerable ) )
    end

    def to_h
      {"jsonrpc" => Rpc::VERSION, "method" => method, "params" => params}
    end

    def to_json
      to_h.to_json
    end

    def to_s
      self.to_json
    end
  end # class Notification
end # module Rpc
