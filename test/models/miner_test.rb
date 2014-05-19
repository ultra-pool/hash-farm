require 'test_helper'

class MinerTest < ActiveSupport::TestCase
  test "it should compute balances" do
    assert_equal 0, miners(:one).balance
    assert_equal 0.1, miners(:two).balance
    assert_equal 0.2, miners(:toto).balance
  end

  test "it should know if a user is payable" do
    refute miners(:one).payable?
    assert miners(:two).payable?
    assert miners(:toto).payable?
  end
end
