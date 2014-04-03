require 'rubygems'
require 'rake'

desc "Coin admin"
namespace :coin do
  desc "Start all coin deamon."
  task :start => :environment do |t|
    Coin.all.each &:restart_deamon
    Coin["BTC"].testnet_start_deamon
	end

  desc "Stop all coin deamon."
  task :stop => :environment do |t|
    Coin.all.each &:stop_deamon
    Coin["BTC"].testnet_stop_deamon
  end
end # namespace :coin

