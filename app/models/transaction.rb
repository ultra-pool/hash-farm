# -*- encoding : utf-8 -*-

require 'core_extensions'
require 'loggable'

# using CoreExtensions

class Transaction < ActiveRecord::Base
  include Loggable

  attr_reader :inputs, :outputs
  # You can't modify a Transaction, you must create it with new and call send_it!
  #protected :save, :save! , :create, :create!, :update, :update!
  
  private
  # Set txid, ourid and block only readable.
  def raw=(v) super end
  def txid=(v) super end
  def ourid=(v) super end
  def block=(v) super end
  public

  def initialize( *args, **kargs )
    objArg = OpenStruct.new(**kargs)
    @inputs = objArg.delete(:inputs) || []
    @outputs = objArg.delete(:outputs) || {}
    @outputs.default = 0
    @rpc = objArg.delete(:rpc)

    super( *args, **objArg.to_h )
  end

  # 
  def add_input( *args )
    txid, vout, amount = *args if args.size >= 2
    txid, vout, amount = args.first.each_pair.to_a.to_h.values_at(:txid, :vout, :amount) if args.size == 1 && args.first.kind_of?( OpenStruct )
    txid, vout, amount = args.first.values_at("txid", "vout", "amount") if args.size == 1 && args.first.kind_of?( Hash )
    raise ArgumentError, "Invalid txid" if ! txid.kind_of?( String ) && txid.size != 64
    raise ArgumentError, "Invalid vout" if ! vout.kind_of?( Integer )

    amount = @rpc.gettransaction(txid)["amount"] * 10**8 if amount.nil?
    raise ArgumentError, "Invalid amount" if ! amount.kind_of?( Integer )

    @inputs << {txid: txid, vout: vout, amount: amount.to_i}
  end

  # output_address is a BTC address, a User or an Account.
  # amount is in Satoshi.
  def add_output( output_address, amount )
    output_address = output_address.payout_address if output_address.kind_of?( User )
    @outputs[output_address] += amount.to_i
  end

  def total_input
    @inputs.map { |i| i[:amount]}.sum
  end

  def total_output
    @outputs.values.sum
  end

  def fees
    total_input - total_output
  end

  def get_raw_unsigned
    inputs = @inputs.map { |h| h = h.dup; h.delete("amount"); h }
    outputs = {}
    @outputs.each { |k,v| outputs[k] = (v * 10**-8).to_f }
    @rpc.createrawtransaction( inputs, outputs )
  end

  def get_raw_signed
    raw = get_raw_unsigned
    res = @rpc.signrawtransaction( raw )
    return nil unless res["complete"]
    res["hex"]
  end

  def get_ourid
    MiningHelper.hash_payout( @inputs, @outputs )
  end

  # options :
  #   - percent: 0.02 => Fees are max 2% of total_input.
  #   - fix: 10**7 => Fees are max 0.1 COIN.
  def check_valid( options={} )
    raise "outputs > inputs" unless total_output <= total_input
    raise "Fees are too high : #{fees.to_f / total_input} > #{options[:percent]}" unless options[:percent].nil? || fees < total_input * options[:percent]
    raise "Fees are too high : #{fees} > #{options[:fix]}" unless options[:fix].nil? || fees <= options[:fix]
    true
  end

  def send_it!(force=false)
    raise 'Transaction is alreay on network' if self.txid
    check_valid(percent: 0.005) unless force
    self.raw = get_raw_signed()
    res = @rpc.sendrawtransaction( self.raw )
    self.txid = res.to_s
    self.ourid = get_ourid
    log.info "Sending transaction #{txid[0...8]} : #{total_input} from #{@inputs.size} inputs to #{@outputs.size} outputs (- #{fees} fees)."
    save!
  end

  def search_block_height
    get_info["blockhash"]
  rescue => err
    log.error err
    nil
  end

  # Get info from network
  def get_info
    infos = @rpc.gettransaction( self.txid )
    self.update!( block: infos["blockhash"] ) if ! self.block && infos["blockhash"]
    infos
  end

  def mature?( miniconf=6 )
    get_info["confirmations"] >= miniconf
  end

  def immature?( miniconf=6 )
    ! mature?( miniconf )
  end

  def to_h
    {
      inputs: @inputs,
      outputs: @outputs,
      txid: txid,
      ourid: ourid,
    }
  end

  def inspect
    to_h.inspect
  end
end
