
require 'socket'
require 'protocol/rpc/handler'

module PM
  module CommandServer
    include Loggable
    include Rpc::Handler.dup

    def post_init
      super

      CommandServer.log.debug "Connexion to CommandServer received from #{ip_port}"
      @ms = MainServer.instance

      on( "request" ) do |req|
        begin
          method = req.method.split('.')
          case method.first
          when "stop"
            CommandServer.log.info "'stop' request received. Going to shutdown HashFarm...";
            req.respond( true )
            @ms.on('stopped') do EM.stop_event_loop end
            @ms.stop
          when "stats"
            req.respond( stats )
          when "jstats"
            req.respond( jstats )
          when "set_pool"
            pool_name = req.params.first
            if pool_name != "none"
              pool = @ms.pools.find { |p| p.name == pool_name }
              req.respond( pool.present? ? true : [ false, @ms.pools.map(&:name) ] )
              @ms.current_pool = pool if pool.present?
            else
              @ms.current_pool = nil
              req.respond true
            end
          when "add_fake_rent_pool"
            raise "Command available only with RentServer, not #{@ms.class}" unless @ms.kind_of?( RentServer )

            url = req.params.first
            pay = Float( req.params[1] ) rescue Order::PAY_MIN
            price = Float( req.params[2] ) rescue 0.001
            limit = Float( req.params[3] ) rescue nil
            prev_hashrate = [@ms.hashrate * 10**-6, limit || Float::INFINITY].min
            puts "New RentPool @#{URI(url).host} for ~#{(pay / price * 1.day / prev_hashrate).fround} s at #{prev_hashrate} MHs"
            order = Order.new(user_id: 1, url: url, pay: pay, price: price, limit: limit)
            if order.valid?
              @ms.add_rent_pool( order )
              req.respond true
            else
              req.respond false
            end
          when "reload"
            Dir["lib/*.rb"].each { |f|
              next if f =~ /market\.rb$/
              puts "Reload #{f}"; load f
            }
            Dir["lib/pool/**.rb"].each { |f| puts "Reload #{f}"; load f }
            req.respond true
          else
            req.respond "Unknow method : '#{method.first}'"
          end
        rescue => err
          req.respond false
          CommandServer.log.error "#{err}\n" + err.backtrace[0..2].join("\n")
          CommandServer.log.error "with request #{req}"
        end
      end
      on( "notification" ) do |notif|
        begin
          method = notif.method.split('.')
          case method.first
          when "block.mining"
            coin_code, hash = *notif.params
            pool = @ms.pools.find { |p| name =~ /^#{coin_code}/ }
            if pool.present?
              pool.block_notify( hash )
            else
              CommandServer.log.warn "Block notification received for #{coin_code} but pool is not launch."
            end
          else
            CommandServer.log.warn "Unknow method : '#{method.first}'"
          end
        rescue => err
          CommandServer.log.error "#{err}\n" + err.backtrace[0..2].join("\n")
          CommandServer.log.error "with notification #{notif}"
        end
      end
    end

    def stats
      s = StringIO.new
      s.puts "HashFarm :"
      s.puts "- %d workers, %.1f MH/s, %.1f %% rejected" % [@ms.workers.size, @ms.hashrate * 10**-6, @ms.hashrate > 0 ? @ms.rejected_hashrate.to_f / @ms.hashrate : 0]
      # @ms.balances.each do |name, b|
      #   s.puts "#{b} #{name},"
      # end
      if @ms.current_pool
        s.puts "- current pool : #{@ms.current_pool.name}"
      else
        @ms.pools.each do |p|
          s.puts p.to_s
          # s.puts "- #{p.name} :"
          # s.puts "\t* %d workers, %.1f MH/s" % [p.workers.size, p.hashrate * 10**-6]
          # s.puts "\t* %.2f mBTC / MH/s / day," % (p.profitability * 1000)
        end
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