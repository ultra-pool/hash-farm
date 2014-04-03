require 'rubygems'
require 'rake'

desc "ProfitMining Multicoin pool admin"
namespace :profit_mining do

  desc "Start a ProfitMining instance."
  task :start => :environment do |t|
    require 'pool/main_server'
    require 'command_server'

    pm_server = MainServer.instance
    pm_server.start

    Signal.trap("TERM")  { puts "'TERM' signal received. Going to shutdown ProfitMining..."; pm_server.stop; EM.stop }
    Signal.trap("INT")  { puts "'INT' signal received. Going to shutdown ProfitMining..."; pm_server.stop; EM.stop }

    EM.reactor_thread.join
  end # task :start

  namespace :block do
  desc "Start a ProfitMining instance."
    task :notify => :environment do |t|
      coin_code, hash = *ARGV[1..2]
      # 
      task coin_code.to_sym do ; end
      task hash.to_sym do ; end

      cs = config.command_server
      client = Stratum::Client.new( cs.host, cs.port )
      client.connect
      client.block.mining( coin_code, hash )
      client.close
    end
  end

end # namespace :profit_mining
