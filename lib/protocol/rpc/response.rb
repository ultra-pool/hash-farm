# -*- encoding : utf-8 -*-

module Rpc
  # class Response
    # #
    # alias_method :new2, :new
    
    # def self.new(arg1, id)
    #   if arg1.kind_of? Exception
    #     ErrorResponse.new2(arg1, id)
    #   else
    #     Response.new2(arg1, id)
    #   end
    # end

  #   attr_reader :id, :result
    
  #   def initialize(result, id)
  #     @id = id
  #     @result = result
  #   end

  #   def to_h
  #     h = {"jsonrpc" => Rpc::VERSION, "id" =>  id}
  #     h.merge!("result" => result) unless result.nil?
  #     h
  #   end

  #   def to_json
  #     to_h.to_json
  #   end

  #   def to_s
  #     to_json + "\n"
  #   end
  # end

  class Response < Rpc::Message
    class << self
      private :new
      def factory( resp, ref=nil )
        if resp.kind_of?( Hash ) && ( resp.key?("result") && resp["id"] )
          ResultResponse.new( resp["result"], resp["id"] )
        elsif resp.kind_of?( Hash ) && resp.key?("error")
          ErrorResponse.new( resp["error"], resp["id"] )
        elsif resp.kind_of?( Response )
          resp
        elsif resp.kind_of?( Exception )
          ErrorResponse.new( resp, ref )
        elsif ref.present?
          ResultResponse.new( resp, ref )
        else
          raise "resp is a #{resp.class} so a ref is required to create a ResultResponse."
        end
      end
    end

    attr_reader :id

    def initialize( ref )
      if ref.kind_of?( Rpc::Request )
        @id = ref.id
      elsif ref.kind_of?( Integer ) || ref.kind_of?( String )
        @id = ref
      else
        raise "id must be an Integer or a String"
      end
    end

    def result?
      false
    end

    def error?
      false
    end

    def to_h
      {"jsonrpc" => Rpc::VERSION, "id" =>  id}
    end

    def to_json
      to_h.to_json
    end
    alias_method :inspect, :to_json

    def to_s
      to_json
    end
  end # class Response

  class ResultResponse < Response
    def ResultResponse.new(*) super end

    attr_reader :result

    def initialize(result, ref)
      raise "ref may not be nil for a ResultResponse" if ref.nil?
      super( ref )
      @result = result
    end

    def result?
      true
    end

    def to_h
      super.merge( "result" => @result )
    end
  end # class ResultResponse

  class ErrorResponse < Response
    def ErrorResponse.new(*) super end

    attr_reader :error

    def initialize( error, id=nil )
      id = error.id if id.nil? && error.kind_of?( Rpc::Error )
      super( id || "null")
      @error = error
    end

    def error?
      false
    end

    def to_h
      super.merge( "error" => error.to_h )
    end
  end # class ErrorResponse
end # module Rpc
