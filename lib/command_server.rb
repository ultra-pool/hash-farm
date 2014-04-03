
require 'socket'
require 'protocol/rpc/handler'

module PM
  module CommandServer
    include Loggable
    include Rpc::Handler.dup

    def post_init
      init_rpc_handler
      CommandServer.log.debug "Connexion to CommandServer received from #{ip_port}"
      @ms = MainServer.instance

      on( "request" ) do |req|
        method = req.method.split('.')
        case method.first
        when "stop"
          CommandServer.log.info "'stop' request received. Going to shutdown ProfitMining...";
          req.respond( true )
          @ms.stop
          EM.stop
        when "stats"
          req.respond( stats )
        when "jstats"
          req.respond( jstats )
        else
          req.respond "Unknow method : '#{method.first}'"
        end
      end
      on( "notification" ) do |notif|
        method = notif.method.split('.')
        case method.first
        when "block.mining"
          coin_code, hash = *notif.params
          pool = @ms.pools.find { |p| name =~ /^#{coin_code}/ }
          if pool.present?
            pool.block_notify( hash ) 
          else
            log.warn "Block notification received for #{coin_code} but pool is not launch."
          end
        else
          log.warn "Unknow method : '#{method.first}'"
        end
      end
    end

    def stats
      s = StringIO.new
      s.puts "ProfitMining :"
      s.puts "- %d workers, %.1f MH/s, %.1f %% rejected" % [@ms.workers.size, @ms.hashrate * 10**-6, @ms.hashrate > 0 ? @ms.rejected_hashrate.to_f / @ms.hashrate : 0]
      # @ms.balances.each do |name, b|
      #   s.puts "#{b} #{name},"
      # end
      @ms.pools.each do |p|
        s.puts "- #{p.name} :"
        s.puts "\t* %d workers, %.1f MH/s" % [p.workers.size, p.hashrate * 10**-6]
        s.puts "\t* %.2f mBTC / MH/s / day," % (p.profitability * 1000)
      end
      s.string
    end

    def jstats
      {
        workers_count: @ms.workers.count,
        hashrate: @ms.hashrate,
        rejected_percent: @ms.rejected_hashrate,
        balances: [],
        pools: @ms.pools.map { |name, p|
          [name, {
            hashrate: p.hashrate,
            profitability: p.profitability,
            workers_count: p.workers.size,
          } ]
        }.to_h,
      }
    end
  end # module CommmandServer
end # module PM