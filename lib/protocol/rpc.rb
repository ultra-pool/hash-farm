# -*- encoding : utf-8 -*-

require_relative "./rpc/errors"
require_relative "./rpc/notification"
require_relative "./rpc/request"
require_relative "./rpc/response"

module Rpc
  VERSION = "2.0"
  
  autoload(:Handler, "protocol/rpc/handler")
end
