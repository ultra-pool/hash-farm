# -*- encoding : utf-8 -*-

require 'open-uri'
require 'openssl'
require 'net/http'
require 'json'

require_relative '../market'

# Doc : https://www.coins-e.com/exchange/api/documentation/
class CoinsE < Market

  # => Array of String
  def self.supported_currencies
    coins.map { |h| h["coin"] }
  end

  # => Boolean
  def self.support?(from, to)
    pair = "#{from}_#{to}"
    !! markets.find { |h| h["pair"] == pair }
  end

  # => Float
  def self.last_trade from, to
    pair = "#{from}_#{to}"
    market = data[pair]
    market["marketstat"]["ltp"].to_f
  end

  # => Array of Hash
  # Each hash contains :
  # "status": "healthy",
  # "c2": "BTC",
  # "c1": "WDC",
  # "trade_fee": "0.00300000",
  # "coin2": "bitcoin",
  # "coin1": "worldcoin",
  # "pair": "WDC_BTC"
  def self.markets
    get("https://www.coins-e.com/api/v2/markets/list/")["markets"]
  end

  # => Array of Hash
  # Each hash contains :
  # "confirmations": 4,
  # "trade_fee_percent": "0.30",
  # "trade_fee": "0.003",
  # "status": "maintanance",
  # "tier": 1,
  # "name": "bitcoin",
  # "block_time": 600,
  # "withdrawal_fee": "0.00050000",
  # "coin": "BTC",
  # "confirmation_time": 2400,
  # "folder_name": "bitcoin"
  def self.coins
    return get("https://www.coins-e.com/api/v2/coins/list/")["coins"]
  end

  # => Hash of String => Hash
  # "RED_BTC": {
  #   "status": "healthy",
  #   "c2": "BTC",
  #   "c1": "RED",
  #   "marketstat": {
  #     "ltq": "56.70000000",
  #     "ltp": "0.00000299",
  #     "total_bid_q": "1986391.93245100",
  #     "total_ask_q": "169909.00000000",
  #     "bid": "0.00000550",
  #     "24h": {
  #       "volume": "6396.70000000",
  #       "h": "0.00000299",
  #       "avg_rate": "0.00000056",
  #       "l": "0.00000054"
  #     },
  #     "bid_q": "2000.00000000",
  #     "ask": "0.00000900",
  #     "ask_q": "2000.00000000"
  #   },
  #   "marketdepth": {
  #     "bids": [
  #       {
  #         "q": "2000.00000000",
  #         "cq": "2000.00000000",
  #         "r": "0.00000550",
  #         "n": 1
  #       },
  #     ],
  #     "asks": [
  #       {
  #         "q": "2000.00000000",
  #         "cq": "2000.00000000",
  #         "r": "0.00000900",
  #         "n": 1
  #       },
  #     ]
  #   }
  # }
  def self.data
    return get("https://www.coins-e.com/api/v2/markets/data/")["markets"]
  end

  # => Hash
  # like data above, but with just
  # "bids": [ {} ]
  # "asks": [ {} ]
  def self.market_depth from, to
    pair = "#{from}_#{to}"
    return get("https://www.coins-e.com/api/v2/market/#{pair}/depth/")["marketdepth"]
  end

  # => Array of Hash
  # "pair": "WDC_BTC",
  # "buy_order_no": "6402043891679232",
  # "id": "0.76124500/5909462682435584-1.52249000/6402043891679232",
  # "rate": "1.52249000",
  # "created": 1372442273,
  # "quantity": "2.45600000",
  # "status": "settled",
  # "sell_order_no": "5909462682435584"
  def self.trades from, to
    return get("https://www.coins-e.com/api/v2/market/#{from}_#{to}/trades/")["trades"]
  end

  private
    #
    def self.get url
      hash = Market.get(url)
      raise hash["message"] if ! hash["status"]
      hash
    end
end
