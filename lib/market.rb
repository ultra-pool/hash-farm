# -*- encoding : utf-8 -*-

# When subclassing Market,
# you MUST reimplement supported_currencies, support? and last_trade.
class Market
  AVAILABLE = []

  def self.inherited subclass
    Market::AVAILABLE << subclass
  end

  # => Array of String
  def self.supported_currencies
    AVAILABLE.collect_concat(&:supported_currencies).uniq
  end

  # => Array of String
  def self.supported_scrypt_currencies
    supported_currencies.select { |cur| Coin::SCRYPT_COINS[cur] != nil }
  end

  # => Boolean
  def self.support?(from, to)
    !! AVAILABLE.find { |market| market.support?( from, to ) }
  end

  # => aHash of String => Float, market's name => last trade value
  def self.last_trades from, to
    trades = AVAILABLE.map do |market|
      [market.name, market.last_trade(from, to)] if market.support?(from, to) rescue nil
    end.compact
    Hash[ trades ]
  end

  # => Float
  def self.best_last_trade from, to
    self.last_trades(from, to).values.max
  end

  private
    @@cache = {}
    #
    def self.get url, refresh_rate=60
      return @@cache[url].last if @@cache[url] && @@cache[url].first + refresh_rate > Time.now
      uri = URI(url)
      if uri.scheme == "https"
        agent = Net::HTTP.new( uri.hostname, uri.port )
        agent.use_ssl = true
        res = agent.get( uri.path + (uri.query && '?' + uri.query).to_s + (uri.fragment && '#' + uri.fragment).to_s )
      else
        res = Net::HTTP.get_response(uri)
      end
      raise "HTTPError #{res.code} : #{res.message}" if res.code != "200"
      hash = JSON.parse( res.body )
      @@cache[url] = [Time.now, hash]
      hash
    rescue => err
      raise if ! @@cache[url]
      puts err
      @@cache[url].last
    end
end unless defined? Market

# Load all markets files to make them available via Market methods.
# Dir["lib/markets/*.rb"].each {|file| require file }
