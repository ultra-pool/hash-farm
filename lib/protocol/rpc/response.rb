# -*- encoding : utf-8 -*-

module Rpc
  class Response
    # #
    # alias_method :new2, :new
    
    # def self.new(arg1, id)
    #   if arg1.kind_of? Exception
    #     ErrorResponse.new2(arg1, id)
    #   else
    #     Response.new2(arg1, id)
    #   end
    # end

    attr_reader :id, :result
    
    def initialize(result, id)
      @id = id
      @result = result
    end

    def to_h
      h = {"jsonrpc" => Rpc::VERSION, "id" =>  id}
      h.merge!("result" => result) unless result.nil?
      h
    end

    def to_json
      to_h.to_json
    end

    def to_s
      to_json + "\n"
    end
  end

  class ErrorResponse < Response
    attr_reader :error

    def initialize(error, id=nil)
      super(nil, id || error.id)
      @error = error
    end

    def to_h
      super.merge("error" => error.to_h)
    end
  end # class Response
end # module Rpc
