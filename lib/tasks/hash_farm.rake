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

    Signal.trap("TERM") do
      puts "'TERM' signal received. Going to shutdown HashFarm..."
      EM.add_timer(0) { pm_server.stop; EM.stop }
    end
    Signal.trap("INT") do
      puts "'INT' signal received. Going to shutdown HashFarm..."
      EM.add_timer(0) { pm_server.stop; EM.stop }
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
