require 'rubygems'
require 'rake'

require 'tx_watcher'

desc "HashFarm Multicoin pool admin"
namespace :watcher do

  desc "Generate a new serialized seed for deposit addresses"
  # rake hash_farm:gen_seed[deadbeef]
  task :watch => :environment do |t|
    Watcher.run
  end
end