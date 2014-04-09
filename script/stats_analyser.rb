# -*- encoding : utf-8 -*-

require "yaml"
require 'octave'

engine = Octave::Engine.new
engine.eval( "close all" )

plot_colors = {
  "middlecoin" => "-g+",
  "coinshift" => "-r+",
  "we_mine_all" => "-b+",
  "profit_mining" => "-k",
  "best_strat" => "yo",
  "worst_strat" => "co",
  "rand_strat" => "mo",
}

# Récupération et normalisation des données :
# -------------------------------------------

# 1) On récupère les données où il y a suffisemment de Hashrate le plus longtemps d'affilé possible et on supprime les doublons
pools = ["middlecoin", "coinshift", "we_mine_all"].map { |pool|
  puts "Getting data for #{pool}... "
  tab = YAML.load( open("db/stats/#{pool}.yaml") )
  print "#{tab.size} inputs, "
  tab.each_with_index { |h,i|
    tab.delete_at(i) if i > 0 && (h[:timestamp] - tab[i-1][:timestamp]).abs < 2.minutes
  }
  puts "#{tab.size} without doublon"

  chunks = tab.chunk { |h| h[:accepted_mh] > 10 }.select(&:first).map(&:last)
  puts "#{chunks.size} chunks :"
  lengths = chunks.map { |chunk|
    s = chunk.first[:timestamp]
    e = chunk.last[:timestamp]
    l = (chunk.last[:timestamp] - chunk.first[:timestamp]).round(-1)
    [s, e, l, chunk]
  }
  puts lengths.map { |s,e,l,chunk| "#{s} to #{e} (#{l} sec)" }

  longer = lengths.max_by { |s,e,l,chunk| l }.last
  [pool, longer]
}.to_h

# 2) Pour chaque jeux de donnée, modifier les timestamps pour qu'ils commencent tous en même temps,
# et soit des multiple de 10.
pools.each do |pool, stats|
  min = stats.first[:timestamp]
  stats.each { |h| h[:timestamp] = (h[:timestamp] - min).round(-1) }
end

# 2-bis) On prend la mêmes durée
last_time = pools.values.map(&:last).map { |h| h[:timestamp] }.min
puts "End time is #{last_time}"
pools.values.each { |stats| stats.select! { |h| h[:timestamp] <= last_time } }

# 2-ter) On comble les éventuels trous
# times = pools.values.flat_map { |stats| stats.map { |h| h[:timestamp] } }.uniq.sort
# puts "there is #{times.size} times"
# pools.each { |pool, stats|
#   puts "#{pool} : before #{stats.size}"

#   i = 0
#   while i < times.size && stats[i][:timestamp] != times[i]
#     h = stats[i].dup
#     h[:timestamp] = times[i]
#     stats.unshift( h )
#     i += 1
#   end
#   puts "between #{stats.size}"

#   times.each_with_index do |t,i|
#     next if i < stats.size && stats[i][:timestamp] == t
#     h = stats[i-1].dup
#     h[:timestamp] = t
#     stats.insert( i, h )
#   end

#   puts "after #{stats.size}"
# }

# 3) On calcule les gains à cet instant pour chaque pool.
pools.each do |pool, stats|
  stats[0][:total_balance] = stats[0].values_at( :immature, :unexchanged, :balance, :paid ).sum
  stats[0][:gain] = 0
  stats[1..-1].each_with_index { |h,i|
    h[:total_balance] = h.values_at( :immature, :unexchanged, :balance, :paid ).sum
    h[:gain] = h[:total_balance]
    h[:gain] -= stats[i][:total_balance]
  }
end

puts "Total gains :"
pools.each { |pool, stats|
  tot_gains = stats.map { |h| h[:gain] }.sum
  puts "#{pool} : #{tot_gains}"
}

# 4) On divise chaque gain par le hashrate à ce moment là, pour avoir du gain par MH/s
pools.each do |pool, stats|
  stats.each { |h|
    hashrate = h.values_at( :accepted_mh, :rejected_mh ).sum
    h[:gain] /= hashrate if hashrate != 0.0
    h[:gain] = (h[:gain] * 10**8).to_i
  }
end

puts "Total Satoshi per MH/s :"
pools.each { |pool, stats|
  tot_gains = stats.map { |h| h[:gain] }.sum
  puts "#{pool} : #{tot_gains}"
}

# 5) On crée le tableau
profits = pools.map { |pool, stats|
  [pool, stats.map { |h| h.values_at(:timestamp, :gain)} ]
}.to_h
$profits = profits
# 6) On affiche les données brutes
# pp profits

engine.driver.feval( "plot", *profits.flat_map { |pname, stats| [ stats.map(&:first), stats.map(&:last), plot_colors[pname] ] } )
engine.eval( "title('Raw data')" )
engine.driver.feval( "xlabel", "minutes")
engine.driver.feval( "ylabel", "Satoshi par MH/s")
engine.driver.feval( "legend", *profits.keys )
engine.eval("figure")


# Compute ProfitMining profitability :
# ------------------------------------

$result = [0.5,1,3,6].map(&:hour).map { |interval|
  profs = profits.map { |pname, gains|
    # on somme les gains reçu durant cet interval
    g = gains.group_by { |time, gain| time.to_i / interval.to_i * interval }.map { |time, tabs| [time, tabs.map(&:last).sum] }
    # g => un Array de (time, gains)
    [pname, g]
  }.to_h
  profs_real = profs.dup

  best_pool = profs_real.max_by { |pname, stats| stats[0].last }.first
  profs['profit_mining'] = [[0, 0]]
  for i in 1...profs.first.last.size
    profs['profit_mining'] << [ profs[best_pool][i].first, profs[best_pool][i].last ]
    best_pool = profs_real.max_by { |pname, stats| stats[i].last }.first
  end

  profs['best_strat'] = [[0, 0]]
  for i in 1...profs.first.last.size
    profs['best_strat'] << profs_real.values.map { |stats| stats[i] }.max_by { |t,g| g }
  end

  profs['worst_strat'] = [[0, 0]]
  for i in 1...profs.first.last.size
    profs['worst_strat'] << profs_real.values.map { |stats| stats[i] }.min_by(&:last)
  end

  profs['rand_strat'] = [[0, 0]]
  for i in 1...profs.first.last.size
    profs['rand_strat'] << profs_real.values.map { |stats| stats[i] }.sample
  end

  legends = profs.map { |pool, stats| "#{pool} #{stats.map(&:last).sum.round(-2)} Sat" }
  engine.driver.feval( "plot", *profs.flat_map { |pname, stats| [ stats.map(&:first), stats.map(&:last), plot_colors[pname] ] } )
  # engine.driver.feval( "plot", profs['profit_mining'].map(&:first), profs['profit_mining'].map(&:last), plot_colors['profit_mining'] )
  engine.eval( "title('Gains during interval #{interval}')" )
  engine.eval( "xlabel('minutes')" )
  engine.eval( "ylabel('Satoshi par MH/s')" )
  engine.driver.feval( "legend", *legends )
  engine.eval("figure")

  [interval, profs]
}.to_h

$result[:raw] = profits
