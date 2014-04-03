# -*- encoding : utf-8 -*-

module Rpc
  class Error < StandardError
    CODES = {
      "ParseError" => -32700,
      "InvalidRequest" => -32600,
      "MethodNotFound" => -32601,
      "InvalidParams" => -32602,
      "InternalError" => -32603,
    }
    attr_reader :code, :message, :extra
    attr_accessor :id

    def initialize(extra={}, code=nil)
      @message = self.class.name.split('::').last
      @code = code || CODES[@message] || CODES["InternalError"]
      @id = extra.delete(:id)
      @extra = extra
    end

    def data
      { "backtrace" => backtrace }.merge( @extra ).delete_if { |_, v| v.nil? }
    end

    def to_h
      res = {}
      res["code"] = @code
      res["message"] = @message
      res["data"] = data
      res
    end

    def inspect
      to_s + "\n" + backtrace.join("\n")
    end
    def to_s
      "%s : %s (%s).%s" % [
        self.class.name,
        @message,
        @code,
        @extra.empty? ? '' : "\n" + @extra.map { |k,v| "- %s: %s" % [k,v] }.join("\n")
      ]
    end
  end

  class ParseError < Error
  end

  class InvalidRequest < Error
  end

  class MethodNotFound < InvalidRequest
  end

  class InvalidParams < InvalidRequest
  end

  class InternalError < InvalidRequest
  end

  class ServerError < Error
    def initialize( code, data=nil )
      super( data, code )
    end
  end
end
