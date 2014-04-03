# -*- encoding : utf-8 -*-

require_relative "./rpc"

module Stratum

  autoload(:Handler, "protocol/stratum/handler")
  autoload(:Client, "protocol/stratum/client")
  autoload(:Server, "protocol/stratum/server")
  autoload(:Proxy, "protocol/stratum/proxy")

=begin
Stratum::Errors
20 - Other/Unknown
21 - Job not found (=stale)
22 - Duplicate share
23 - Low difficulty share
24 - Unauthorized worker
25 - Not subscribed 
=end
end
