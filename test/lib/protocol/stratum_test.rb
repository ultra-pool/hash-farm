# -*- encoding : utf-8 -*-

if __FILE__ == $0
  Dir[__dir__+"/stratum/**/*_test.rb"].each do |test_file|
    require test_file
  end
end
