# -*- encoding : utf-8 -*-

require 'open-uri'
require 'openssl'
require 'net/http'
require 'json'

require_relative '../market'

# Doc : https://vircurex.com/welcome/api
class Vircurex < Market

  # => Array of String
  def self.supported_currencies
    CURRENCIES
  end

  # => Boolean
  def self.support?(from, to)
    supported_currencies.include?(from) && supported_currencies.include?(to)
  end

  # => Float
  def self.last_trade from, to
    get_last_trade( from, to )["value"].to_f
  end

  BASE_API_URL = "https://api.vircurex.com/api/"
  CURRENCIES = ["ANC", "BTC", "DGC", "DOGE", "DVC", "FRC", "FTC", "I0C", "IXC", "LTC", "NMC", "NVC", "PPC", "QRK", "TRC", "WDC", "XPM"]

  # Returns the lowest asking price for a currency pair. Specify the base and alt currency name.
  def self.get_lowest_ask base, alt
    get "get_lowest_ask", "base" => base, "alt" => alt
  end

  # Returns the highest bid price for a currency pair. Specify the base and alt currency name.
  def self.get_highest_bid base, alt
    get "get_highest_bid", "base" => base, "alt" => alt
  end

  # Returns executed unitprice of the last trade for a currency pair. Specify the base and alt currency name.
  def self.get_last_trade base, alt
    get "get_last_trade", "base" => base, "alt" => alt
  end

  # Returns the trading volume within the last 24 hours for a currency pair. Specify the base and alt currency name.
  def self.get_volume base, alt
    get "get_volume", "base" => base, "alt" => alt
  end

  # Returns a summary information for all supported currencies
  # Return a Hash[base][alt]
  # - highest_bid. Ex: "0.0005653"
  # - last_trade. Ex: "0.05263157"
  # - lowest_ask. Ex: "0.99983443"
  # - volume. Ex: "0.0"
  def self.get_info_for_currency
    get "get_info_for_currency"
  end

  # Returns a summary information for a currency pair
  def self.get_info_for_1_currency base, alt
    get "get_info_for_1_currency", "base" => base, "alt" => alt
  end

  # Returns the complete orderbook for the given currency pair. Note: mutliple items may appear for the same price
  def self.orderbook base, alt
    get "orderbook", "base" => base, "alt" => alt
  end

  # Returns the complete orderbook for all currency pair for alt given. This is more efficient than calling api/orderbook for each combination
  def self.orderbook_alt alt
    get "orderbook_alt", "alt" => alt
  end

  # Returns all executed trades of the past 7 days. If the parameter "since" is provided, then only trades with an order ID greater than "since" will be returned. The function will return a max. of 1000 trades, hence you will need to take the ID of the last returned trade and pass it in the parameter "since" to recall the transaction to traverse through all possible trades within the period of 7 days if required.
  def self.trades base, alt, since=nil
    get "trades", "base" => base, "alt" => alt, "since" => since
  end

  # Returns information about withdrawal fees, number of required confirmations for deposits and max. daily withdrawal
  def self.get_currency_info
    get "get_currency_info"
  end

  # Returns current trading fee. This does not consider possible referral fee reductions, this function returns the general trading fee, e.g. a value of 0.005 is equal to 0.5%
  def self.get_trading_fee
    get "get_trading_fee"
  end

  def initialize account, security_word
    @account, @security_word = account, security_word
  end

  # Notes on the parameters:
  # - Timestamp format: Make sure you have the correct Timezone settings and your timestamp follows the format 2014-01-04T14:00:00 which is equivalent to January 4th, 2014, 2:00 PM. Be sure to use an uppercase letter "T" to separate the date and time and not a space (" ").
  # - The sequence of the parameters is irrelevant. The sequence when putting together the token is crucial.
  # - YourUserName: Provide your login name, not your eMail address. The value is case sensitive.
  # - Securityword: The security word you have entered for the respective API call in your user settings. The value is case sensitive.
  # - Ordertype: values are SELL or BUY
  # - currency: Use the currency short forms, e.g. USD, BTC, NMC, etc.
  # - Prices and quantities: Use . as a decimal seperator. Do not use thousands separator
  # - Otype: Set otype=0 for unreleased orders, otype=1 for released orders

  # Outputs: balance, available_balance
  # Input token: YourSecurityWord;YourUserName;Timestamp;ID;get_balances
  # Note: the security word of this function is the security word from function "get_balance".
  # Output token: YourSecurityWord;YourUserName;Timestamp;get_balances
  def get_balances
    Vircurex.get "get_balances", get_params("get_balances")
  end

  # Provide the name of the currency for which you want to inquire the balance.
  # Outputs: balance, available_balance
  # Input token: YourSecurityWord;YourUserName;Timestamp;ID;get_balance;CurrencyName
  # Output token: YourSecurityWord;YourUserName;Timestamp;get_balance;Balance
  def get_balance currency
    Vircurex.get "get_balance", get_params("get_balance", "currency" => currency)
  end

  # Creates a new order. A maximum of 100 open orders are allowed at any point in time.
  # The order is only saved but not released, hence it will not be traded before you release it.
  # Values for ordertype: BUY, SELL
  # Outputs: orderid
  # Input token: YourSecurityWord;YourUserName;Timestamp;ID;create_order;ordertype;amount;currency1;unitprice;currency2
  # Output token: YourSecurityWord;YourUserName;Timestamp;create_order;order_id
  def create_order ordertype, amount, currency1, unitprice, currency2
    Vircurex.get "create_order", "ordertype" => ordertype, "amount" => amount, "currency1" => currency1, "unitprice" => unitprice, "currency2" => currency2
  end

  # Creates a new order and release it for trading immediately.
  # A maximum of 100 open orders are allowed at any point in time.
  # The order is only saved but not released, hence it will not be traded before you release it. 
  # Values for ordertype: BUY, SELL
  # Outputs: orderid
  # Input token: YourSecurityWord;YourUserName;Timestamp;ID;create_order;ordertype;amount;currency1;unitprice;currency2
  # Output token: YourSecurityWord;YourUserName;Timestamp;create_order;order_id
  def create_released_order ordertype, amount, currency1, unitprice, currency2
    Vircurex.get "create_released_order", "ordertype" => ordertype, "amount" => amount, "currency1" => currency1, "unitprice" => unitprice, "currency2" => currency2
  end

  # Release the order for trading.
  # IMPORTANT: The input orderid is NOT the same as the output orderid, you must use the output orderID for further API calls pertaining to an order.
  # Though the two numbers might be identical, they are independent, unreleased order IDs are not the same as the released order IDs.
  # Outputs: orderid
  # Input token:
  # YourSecurityWord;YourUserName;Timestamp;ID;release_order;orderid
  # Output token:
  # YourSecurityWord;YourUserName;Timestamp;release_order;orderid
  def release_order orderid
    Vircurex.get "release_order", "orderid" => orderid
  end

  # Deletes/closes an order.
  # Outputs: orderid
  # Input token: YourSecurityWord;YourUserName;Timestamp;ID;delete_order;orderid;otype
  # Output token: YourSecurityWord;YourUserName;Timestamp;delete_order;orderid
  def delete_order orderid, otype
    Vircurex.get "delete_order", "orderid" => orderid, "otype" => otype
  end

  # Returns order information
  # Outputs: currency1, currency2, open_quantity, quantity, unitprice, ordertype, orderstatus, lastchangedat, releasedat
  # Input token: YourSecurityWord;YourUserName;Timestamp;ID;read_order;orderid
  # Output token: YourSecurityWord;YourUserName;Timestamp;read_order;orderid
  def read_order orderid, otype
    Vircurex.get "read_order", "orderid" => orderid, "otype" => otype
  end

  # Returns order information for all users' saved or released orders. It does not return information on closed (either manually closed or closed due to order execution) or deleted orders.
  # Outputs: numberorders, otype, and for each order: currency1, currency2, openquantity, quantity, unitprice, ordertype, orderstatus, lastchangedat, releasedat
  # Input token: YourSecurityWord;YourUserName;Timestamp;ID;read_orders
  # Output token: YourSecurityWord;YourUserName;Timestamp;read_order
  def read_orders otype
    Vircurex.get "read_orders", "otype" => otype
  end

  # Returns the order execution info, i.e. the actual trades that were executed against the order.
  # Outputs: currency1, currency2, quantity, unitprice, feepaid, ordertype
  # Input token: YourSecurityWord;YourUserName;Timestamp;ID;read_orderexecutions;orderid
  # Output token: YourSecurityWord;YourUserName;Timestamp;
  def read_orderexecutions orderid
    Vircurex.get "read_orderexecutions", "orderid" => orderid
  end

  private

    def self.paramize params
      params.map { |key, value| value.nil? || value == "" ? "" : "#{key}=#{value}" }.join("&")
    end

    def self.get method, params=nil
      url = "https://api.vircurex.com/api/#{method}.json"
      url += '?' + Vircurex.paramize( params ) if params
      hash = Market.get url
      raise "VircurexError #{hash["status"]} : #{hash["status_text"]}" if hash.kind_of?(Hash) && hash["status"] != nil && hash["status"] != 0
      hash
    end

    def get_params method, args={}
      params = {}
      params["account"] = @account
      params["timestamp"] = Time.now.gmtime.strftime("%Y-%m-%dT%H:%M:%S")
      params["id"] = Digest::SHA2.hexdigest("#{params["timestamp"]}-#{rand}")
      params["token"] = tokenize( params, method, args )
      params.merge!(args)
      params
    end

    def tokenize params, method, args
      s = [@security_word, params["account"], params["timestamp"], params["id"], method].join(';')
      s += ";" + args.values.join(";") if args.size > 0
      Digest::SHA256.hexdigest s
    end

end
