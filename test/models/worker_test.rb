require 'test_helper'

class WorkerTest < ActiveSupport::TestCase
  setup do
    @w = workers(:toto1)
  end

  test 'it should compute hashrate' do
    # Create shares to compute hashrate
    t = populate

    # hashrate = @w.hashrate
    # assert_in_delta MiningHelper.difficulty_to_nb_hash(2**-4) * 9 / 9.minutes, hashrate, 10**3
    # assert_in_delta MiningHelper.difficulty_to_nb_hash(2**-4 * 9) / 9.minutes, hashrate, 10**3
    # assert_equal hashrate, @w.hashrate(t - 10.minutes)
    # assert_equal hashrate, @w.hashrate(since: t - 10.minutes)
    # assert_equal hashrate, @w.hashrate(since: t - 10.minutes, until: t)

    # hashrate = @w.hashrate(since: t - 20.minutes)
    # assert_in_delta MiningHelper.difficulty_to_nb_hash(2**-4 * 10 + 2**-5 * 9) / 19.minutes, hashrate, 10**3

    # assert_in_delta MiningHelper.difficulty_to_nb_hash(2**-5) * 9 / 9.minutes, @w.hashrate(t - 20.minutes, t - 10.minutes - 1), 10**3
    # assert_in_delta MiningHelper.difficulty_to_nb_hash(2**-5) * 9 / 9.minutes, @w.hashrate(since: t - 20.minutes, until: t - 10.minutes - 1), 10**3

    # hashrates = @w.hashrate(since: t - 20.minutes, slice: 10.minutes)
    # assert_equal 2, hashrates.size
    # assert_in_delta MiningHelper.difficulty_to_nb_hash(2**-5 * 9) / 9.minutes, hashrates.first, 10**3
    # assert_in_delta MiningHelper.difficulty_to_nb_hash(2**-4 * 9) / 9.minutes, hashrates.last, 10**3

    hashrate = @w.hashrate( t - 10.minutes, validity: false )
    assert_in_delta MiningHelper.difficulty_to_nb_hash(2**-4) / 9.minutes, hashrate, 10**3

    hashrate = @w.hashrate( t - 10.minutes, validity: true )
    assert_in_delta MiningHelper.difficulty_to_nb_hash(2**-4 * 8) / 9.minutes, hashrate, 10**3
  end

  def populate
    @w.shares.each(&:destroy)
    @w.reload
    t = Time.now

    share = Share.new(worker: @w, difficulty: 2**-5, our_result: true, solution: '', order: orders(:one))
    10.times do |i|
      s = share.dup
      s.created_at = t - 20.minutes + i.minutes
      s.our_result = false if i == 5
      s.save!
      @w.shares << s
    end

    share.difficulty = 2**-4
    10.times do |i|
      s = share.dup
      s.created_at = t - 10.minutes + i.minutes
      s.our_result = false if i == 5
      s.save!
      @w.shares << s
    end
    t
  end
end
