# -*- encoding : utf-8 -*-

require 'open-uri'
require 'openssl'
require 'net/http'
require 'json'

require_relative '../market'

# Doc : https://www.cryptsy.com/pages/api
class Cryptsy < Market

  @@data = nil
  @@market_keys_to_id = nil
  @@market_ids_to_key = nil

  # => Array of String
  def self.supported_currencies
    market_keys_to_id.keys.select { |cur| @@market_keys_to_id[cur]["BTC"] != nil }
  end

  # => Boolean
  def self.support?(from, to)
    !! (market_keys_to_id[from] && market_keys_to_id[from][to])
  end

  def self.init
    data = get_markets_data()
    @@market_keys_to_id = {}
    @@market_ids_to_key = {}
    data.each do |code, market|
      prim, sec, id = market["primarycode"], market["secondarycode"], market["marketid"]
      @@market_keys_to_id[ prim ] ||= {}
      @@market_keys_to_id[ prim ][ sec ] = id
      @@market_keys_to_id[ sec ] ||= {}
      @@market_keys_to_id[ sec ][ prim ] = id
      @@market_ids_to_key[ id ] = code
    end
  end

  def self.market_keys_to_id
    return @@market_keys_to_id if @@market_keys_to_id
    self.init()
    @@market_keys_to_id
  end

  def self.market_ids_to_key
    return @@market_ids_to_key if @@market_ids_to_key
    self.init()
    @@market_ids_to_key
  end

  # => Float
  def self.last_trade from, to
    data = get_markets_data( market_keys_to_id[from][to] )
    last_trade = data["lasttradeprice"].to_f
    if data["primarycode"] == from && data["secondarycode"] == to
      last_trade
    elsif data["primarycode"] == to && data["secondarycode"] == from
      1.0 / last_trade
    else
      raise "Waited last trade from #{from.inspect} to #{to.inspect}, and get #{data["primarycode"].inspect} to #{data["secondarycode"].inspect}"
    end
  end

  # Output : a Hash of markets
  # - buyorders : an Array of 20-max buy orders
  #   - price. Ex: "0.00039468"
  #   - quantity. Ex: "200.00000000"
  #   - total. Ex: "0.07893600"
  # - label : The label/key of the market. Ex "ASC/XPM"
  # - lasttradeprice. Ex: "0.00016799"
  # - lasttradetime. Ex: "2014-01-20 04:38:36"
  # - marketid. Ex: "122"
  # - primarycode. Ex: "ASC"
  # - primaryname. Ex: "AsicCoin"
  # - recenttrades : an Array of 100-max trades
  #   - id. Ex: "16232530"
  #   - price. Ex: "0.00039467"
  #   - quantity. Ex: "200.00000000"
  #   - time. Ex: "2014-01-20 06:14:18"
  #   - total. Ex: "0.07893400"
  # - secondarycode. Ex: "XPM"
  # - secondaryname. Ex: "PrimeCoin"
  # - sellorders : an Array of 20-max sell orders
  #   - price. Ex: "0.00039468"
  #   - quantity. Ex: "200.00000000"
  #   - total. Ex: "0.07893600"
  # - volume. Ex: "321329.34987235"
  def self.get_markets_data market_id=nil
    @@data ||= get("http://pubapi.cryptsy.com/api.php?method=marketdatav2")["markets"]
    if market_id.nil?
      @@data
    else
      # get("http://pubapi.cryptsy.com/api.php?method=singlemarketdata&marketid=#{market_id}")["markets"].values.first
      @@data[ market_ids_to_key[market_id] ]
    end
  end

  # Output : a Hash of markets
  # - buyorders : Array[50]
  # - label : "LTC/BTC"
  # - marketid : "3"
  # - primarycode : "LTC"
  # - primaryname : "LiteCoin"
  # - secondarycode : "BTC"
  # - secondaryname : "BitCoin"
  # - sellorders : Array[50]
  # See market_data doc above for more informations.
  def self.get_orders_data market_id=nil
    if market_id.nil?
      get("http://pubapi.cryptsy.com/api.php?method=orderdata")
    else
      get("http://pubapi.cryptsy.com/api.php?method=singleorderdata&marketid=#{market_id}").values.first
    end
  end

  def initialize pub_key, priv_key
    @pub_key, @priv_key = pub_key, priv_key

    @agent = Net::HTTP.new("www.cryptsy.com", 443)
    @agent.use_ssl = true
  end
  
  # Output :
  # - balances_available : Array of currencies and the balances availalbe for each
  # - balances_hold : Array of currencies and the amounts currently on hold for open orders
  # - servertimestamp : Current server timestamp
  # - servertimezone : Current timezone for the server
  # - serverdatetime : Current date/time on the server
  # - openordercount : Count of open orders on your account
  def get_info
    post "getinfo"
  end

  # Outputs: Array of Active Markets
  # - marketid : Integer value representing a market
  # - label : Name for this market, for example: AMC/BTC
  # - primary_currency_code : Primary currency code, for example: AMC
  # - primary_currency_name : Primary currency name, for example: AmericanCoin
  # - secondary_currency_code : Secondary currency code, for example: BTC
  # - secondary_currency_name : Secondary currency name, for example: BitCoin
  # - current_volume : 24 hour trading volume in this market
  # - last_trade : Last trade price for this market
  # - high_trade : 24 hour highest trade price in this market
  # - low_trade : 24 hour lowest trade price in this market
  # - created : Datetime (EST) the market was created
  def get_markets
    post "getmarkets"
  end

  # Outputs: Array of Deposits and Withdrawals on your account 
  # - currency : Name of currency account
  # - timestamp : The timestamp the activity posted
  # - datetime : The datetime the activity posted
  # - timezone : Server timezone
  # - type : Type of activity. (Deposit / Withdrawal)
  # - address : Address to which the deposit posted or Withdrawal was sent
  # - amount : Amount of transaction (Not including any fees)
  # - fee : Fee (If any) Charged for this Transaction (Generally only on Withdrawals)
  # - trxid : Network Transaction ID (If available)
  def my_transactions
    post "mytransactions"
  end

  # Inputs:
  # - marketid : Market ID for which you are querying
  # 
  # Outputs: 2 Arrays. First array is sellorders listing current open sell orders ordered price ascending. Second array is buyorders listing current open buy orders ordered price descending.
  # - sellprice : If a sell order, price which order is selling at
  # - buyprice : If a buy order, price the order is buying at
  # - quantity : Quantity on order
  # - total : Total value of order (price * quantity)
  def market_orders market_id
    post "marketorders", {"marketid" => market_id}
  end

  # Inputs:
  # - marketid : Market ID for which you are querying
  # - limit : (optional) Limit the number of results. Default: 200
  # 
  # Outputs: Array your Trades for this Market, in Date Decending Order 
  # - tradeid : An integer identifier for this trade
  # - tradetype : Type of trade (Buy/Sell)
  # - datetime :  Server datetime trade occurred
  # - tradeprice : The price the trade occurred at
  # - quantity : Quantity traded
  # - total : Total value of trade (tradeprice * quantity) - Does not include fees
  # - fee : Fee Charged for this Trade
  # - initiate_ordertype : The type of order which initiated this trade
  # - order_id : Original order id this trade was executed against
  def my_trades market_id, limit=nil
    post "mytrades", {"marketid" => market_id, "limit" => limit}
  end

  # Outputs: Array your Trades for all Markets, in Date Decending Order 
  # - tradeid : An integer identifier for this trade
  # - tradetype : Type of trade (Buy/Sell)
  # - datetime : Server datetime trade occurred
  # - marketid : The market in which the trade occurred
  # - tradeprice : The price the trade occurred at
  # - quantity : Quantity traded
  # - total : Total value of trade (tradeprice * quantity) - Does not include fees
  # - fee : Fee Charged for this Trade
  # - initiate_ordertype : The type of order which initiated this trade
  # - order_id : Original order id this trade was executed against
  def all_my_trades
    post "allmytrades"
  end

  # Inputs:
  # - marketid : Market ID for which you are querying
  # 
  # Outputs: Array of your orders for this market listing your current open sell and buy orders. 
  # - orderid : Order ID for this order
  # - created : Datetime the order was created
  # - ordertype : Type of order (Buy/Sell)
  # - price : The price per unit for this order
  # - quantity : Quantity remaining for this order
  # - total : Total value of order (price * quantity)
  # - orig_quantity : Original Total Order Quantity
  def my_orders market_id
    post "myorders", {"marketid" => market_id}
  end

  # Inputs:
  # - marketid : Market ID for which you are querying
  # 
  # Outputs: Array of buy and sell orders on the market representing market depth. 
  # Output Format is:
  # array(
  #   'sell'=>array(
  #     array(price,quantity), 
  #     array(price,quantity),
  #     ....
  #   ), 
  #   'buy'=>array(
  #     array(price,quantity), 
  #     array(price,quantity),
  #     ....
  #   )
  # )
  def depth market_id
    post "depth", {"marketid" => market_id}
  end

  # Outputs: Array of all open orders for your account. 
  # - orderid : Order ID for this order
  # - marketid : The Market ID this order was created for
  # - created : Datetime the order was created
  # - ordertype : Type of order (Buy/Sell)
  # - price : The price per unit for this order
  # - quantity : Quantity remaining for this order
  # - total : Total value of order (price * quantity)
  # - orig_quantity : Original Total Order Quantity
  def all_my_orders
    post "allmyorders"
  end

  # Inputs:
  # - marketid : Market ID for which you are creating an order for
  # - ordertype :Order type you are creating (Buy/Sell)
  # - quantity : Amount of units you are buying/selling in this order
  # - price :Price per unit you are buying/selling at
  # 
  # Outputs: 
  # - orderid : If successful, the Order ID for the order which was created
  def create_order market_id, order_type, quantity, price_per_unit
    post "createorder", {"marketid" => market_id, "ordertype" => order_type, "quantity" => quantity, "price" => price_per_unit}
  end

  # Inputs:
  # - orderid : Order ID for which you would like to cancel
  def cancel_order order_id
    post "createorder", {"orderid" => order_id}
  end

  # Outputs: Array for return information on each order cancelled
  def cancel_all_orders
    post "cancelallorders"
  end

  # Inputs:
  # - ordertype : Order type you are calculating for (Buy/Sell)
  # - quantity : Amount of units you are buying/selling
  # - price : Price per unit you are buying/selling at
  # 
  # Outputs: 
  # - fee : The that would be charged for provided inputs
  # - net : The net total with fees
  def calculate_fees order_type, quantity, price_per_unit
    post "calculatefees", {"ordertype" => order_type, "quantity" => quantity, "price" => price_per_unit}
  end

  # Inputs: (either currencyid OR currencycode required - you do not have to supply both)
  # - currencyid : Currency ID for the coin you want to generate a new address for (ie. 3 = BitCoin)
  # - currencycode : Currency Code for the coin you want to generate a new address for (ie. BTC = BitCoin)
  # 
  # Outputs: 
  # - address : The new generated address
  def generate_new_address currency_id, currency_code
    post "generatenewaddress", {"currencyid" => currency_id, "currencycode" => currency_code}
  end

  private

    def self.get url
      hash = Market.get url
      raise hash["error"] if hash["success"] != 1
      hash["return"]
    rescue Errno::ETIMEDOUT
      retry
    rescue => err
      if err.message =~ /502/
        sleep 5
        retry
      else
        raise
      end
    end

    # Add a nonce to params.
    # Nonce is always sup of the previous call.
    # Return nonce
    def get_nonce
      Digest::SHA2.hexdigest("#{Time.now.to_f}-#{rand}")
    end

    # Return Auth headers.
    def headers_for params
      {"Key"  => @pub_key, "Sign" => Cryptsy.sign( params )}
    end

    # Get HMAC-SHA512 signature of params
    def self.sign params
      digest  = OpenSSL::Digest::SHA512.new
      data = paramize params
      data.encode!('ascii')
      hash = OpenSSL::HMAC.hexdigest( digest, @priv_key, data )
      hash
    end

    # Transform a hash of key/value to POST format key1=value1&key2=value2&...
    # Pair with empty value are removed.
    # TODO : this is a naive implementation : MUST BE IMPROVED !
    def paramize params
      params.map { |key, value| value.nil? || value == "" ? "" : "#{key}=#{value}" }.join("&")
    end

    # Post request to Cryptsy authenticated API
    # params contains input value if any.
    def post method, params={}
      # Prepare request
      params = params.dup
      params["method"] = method
      params["nonce"] = get_nonce
      headers = headers_for params

      # Send request
      p ["/api", paramize(params), headers]
      res = @agent.post( "/api", paramize(params), headers )

      # Process response
      raise "HTTPErrorError #{res.code} : #{res.message}" if res.code != "200"
      hash = JSON.parse res.body
      raise hash["error"] if hash["success"] != 1
      hash["return"]
    end
end