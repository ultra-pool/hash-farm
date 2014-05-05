require 'test_helper'

class UserTest < ActiveSupport::TestCase

  test "it should know the user deposit bitcoin address from a public seed" do
    u = users(:mv)

    HashFarm.config.serialized_master_key = {
      private: nil,
      public: 'xpub661MyMwAqRbcG2V5zGfVX28LzHCBm7BHhEeMun3WjJUJQhmT6SnhpF2m2BXh7bwnbQ3x3oRGW2hjxzkBcCu8oDjNod4cUJT9j5pHoMVFGsE'
    }
    assert_equal('1EmVWFtXja1MM6u6pLjWU2wm9dStXyPXZ9', u.deposit_key.addr)
    assert_equal(nil, u.deposit_key.priv)
  end

  test "it should know the user deposit bitcoin address from a private seed" do
    u = users(:mv)
    HashFarm.config.serialized_master_key = {
      private: 'xprv9s21ZrQH143K3YQctF8V9tBcSFMhMeTSL1im7PduAxwKXuSJYuUTGSiHAuY1r7PTPBkx4M7uMjHJaogx24szcMRVUD3xojm1fN1YqR51FvP',
      public: nil
    }
    assert_equal('1EmVWFtXja1MM6u6pLjWU2wm9dStXyPXZ9', u.deposit_key.addr)
    assert_equal('f4202564a4b5d6d8dcd0eb8ce7bc889ac156ac87822c833779a3be1bee1c1baa', u.deposit_key.priv)
  end

  

end
