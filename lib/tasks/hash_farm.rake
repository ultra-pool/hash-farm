require 'rubygems'
require 'rake'

desc "HashFarm Multicoin pool admin"
namespace :hash_farm do

  desc "Generate a new serialized seed for deposit addresses"
  # rake hash_farm:gen_seed[deadbeef]
  task :gen_seed, [:seed] => :environment do |t, args|
    master = MoneyTree::Master.new seed_hex: args[:seed]
    puts "Master public serialized: " + master.to_serialized_address(:public)
    puts "Master private serialized: " + master.to_serialized_address(:private)
  end

  desc "Start a HashFarm instance."
  task :start => :environment do |t|
    require 'pool/main_server'
    require 'command_server'

    pm_server = MainServer.instance
    pm_server.start

    # pm_server.on( 'stopped' ) { EM.stop }
    pm_server.on( 'stopped' ) {
      puts "\033[31m[%s][HashFarm] PM stopped. Going to stop EM..\033[0m" % Time.now.strftime("%T")
      EM.next_tick { EM.stop }
    }

    Signal.trap("TERM") do
      puts "\033[31m[%s][HashFarm] 'TERM' signal received. Going to shutdown HashFarm...\033[0m" % Time.now.strftime("%T")
      EM.add_timer(0) { pm_server.stop }
    end
    Signal.trap("INT") do
      puts "\033[31m[%s][HashFarm] 'INT' signal received. Going to shutdown HashFarm...\033[0m" % Time.now.strftime("%T")
      EM.add_timer(0) { pm_server.stop }
    end

    EM.reactor_thread.join
  end # task :start

  namespace :block do
  desc "Start a HashFarm instance."
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

end # namespace :hash_farm
