# -*- encoding : utf-8 -*-

require "core_extensions"
require 'listenable'

require_relative './job'

using CoreExtensions

#
# class Stratum::Mining
#
# A member of Stratum::Handler.
# Allow aHandler.mining.do_something, aHandler.mining.on(signal), etc
# instead of aHandler.mining_do_something or aHander.on("mining_signal").
#
# Methods :
#   subscribe
#   unsubscribe
#   authorize
#   submit
#   notify
#   set_difficulty
# Signals :
#   emit( 'subscribe', req )
#   emit( 'subscribed', result )
#   emit( 'unsubscribe', req )
#   emit( 'authorize', req )
#   emit( 'authorized' )
#   emit( 'submit', req )
#   emit( 'notify', req )
#   emit( 'set_difficulty', req )
#
module Stratum
  class MiningHandler
    include Listenable

    def initialize( handler )
      @handler = handler
      @subscribed = false
      @authorized = false
    end

    # Verify that request has good parameters
    # Return true or raise the error
    def validate_request req
      id = req.id if req.respond_to? :id
      method, params = req.method.sub(/^mining\./,''), req.params
      emit_params = [req]

      case method
      when "subscribe"
        raise Rpc::InvalidParams.new( extra_msg: "id MUST be set" ) if id.nil?

      when "unsubscribe"
        raise Rpc::InvalidParams.new( extra_msg: "id MUST be set" ) if id.nil?
        raise Rpc::InvalidParams.new( extra_msg: "params MUST be a not empty Array." ) unless params.kind_of?( Array ) || params.empty?

      when "authorize"
        # Validate arguments
        raise Rpc::InvalidParams.new( extra_msg: "id MUST be set" ) if id.nil?
        raise Rpc::InvalidParams.new( id: id, extra_msg: "params MUST be an Array : #{params.class}" ) unless params.kind_of?( Array )
        name, password = *params
        raise Rpc::InvalidParams.new( id: id, extra_msg: "name" ) unless name.kind_of?( String )
        raise Rpc::InvalidParams.new( id: id, extra_msg: "password" ) unless password.kind_of?( String )

      when "submit"
        raise Rpc::InvalidParams.new( extra_msg: "id MUST be set" ) if id.nil?
        raise Rpc::InvalidParams.new( id: id, extra_msg: "params MUST be an Array : #{params.class}" ) unless params.kind_of?( Array )
        name, job_id, extranonce2, ntime, nonce = *params
        raise Rpc::InvalidParams.new( id: id, extra_msg: "name" ) unless name.kind_of?( String )
        raise Rpc::InvalidParams.new( id: id, extra_msg: "job_id" ) unless job_id.kind_of?( String )
        raise Rpc::InvalidParams.new( id: id, extra_msg: "extranonce2" ) unless extranonce2.kind_of?( String )
        raise Rpc::InvalidParams.new( id: id, extra_msg: "ntime" ) unless ntime.kind_of?( String ) && ntime.hexsize == 4
        raise Rpc::InvalidParams.new( id: id, extra_msg: "nonce" ) unless nonce.kind_of?( String ) && nonce.hexsize == 4

      when "notify"
        raise Rpc::InvalidParams.new( extra_msg: "params MUST be an Array : #{params.class}" ) unless params.kind_of?( Array )
        job_id, prevhash, coinb1, coinb2, merkle_branch, version, nbits, ntime, clean_jobs = *params
        raise Rpc::InvalidParams.new( extra_msg: "job_id" ) unless job_id.kind_of?( String )
        raise Rpc::InvalidParams.new( extra_msg: "prevhash" ) unless prevhash.kind_of?( String )
        raise Rpc::InvalidParams.new( extra_msg: "coinb1" ) unless coinb1.kind_of?( String )
        raise Rpc::InvalidParams.new( extra_msg: "coinb2" ) unless coinb2.kind_of?( String )
        raise Rpc::InvalidParams.new( extra_msg: "merkle_branch" ) unless merkle_branch.kind_of?( Array ) and merkle_branch.all? { |b| b.kind_of?( String ) }
        raise Rpc::InvalidParams.new( extra_msg: "version" ) unless version.kind_of?( String ) && version.hexsize == 4
        raise Rpc::InvalidParams.new( extra_msg: "nbits" ) unless nbits.kind_of?( String ) && version.hexsize == 4
        raise Rpc::InvalidParams.new( extra_msg: "ntime" ) unless ntime.kind_of?( String ) && version.hexsize == 4
        raise Rpc::InvalidParams.new( extra_msg: "clean_jobs" ) unless clean_jobs.boolean?

        job = Stratum::Job.from_stratum( params )
        emit_params = [job]

      when "set_difficulty"
        raise Rpc::InvalidParams.new( extra_msg: "params MUST be an Array : #{params.class}" ) unless params.kind_of?( Array )
        diff = params[0]
        raise Rpc::InvalidParams.new( extra_msg: "diff" ) unless diff.kind_of?( Integer )

        emit_params = [diff]

      else
        raise Rpc::MethodNotFound.new( id: id, method: "mining.#{method}" )
      end

      emit( method, *emit_params )
      true
    rescue => err
      emit( 'error', err, req )
      raise
    end

    # Send mining.subscribe request and call given block with response
    def subscribe *args, &block
      @handler.send_request( "mining.subscribe", args.compact ) { |resp|
        @subscribed = resp.result?
        emit('subscribed', resp.result) if @subscribed
        block.call(resp) if block
      }
      self
    end

    # Send mining.authorize request and call given block with response
    def authorize name, password, &block
      @handler.send_request( "mining.authorize", [name, password] ) { |resp|
        @authorized = resp.result? && resp.result
        emit('authorized') if @authorized
        block.call(resp) if block
      }
      self
    end

    # Send mining.submit request and call given block with response
    def submit name, job_id, extranonce2, ntime, nonce, &block
      method = "mining.submit"
      params = [name, job_id, extranonce2, ntime, nonce]
      @handler.send_request method, params, &block
      self
    end

    # Send mining.unsubscribe request and call given block with response
    def unsubscribe subscriptionID, &block
      @handler.send_request "mining.unsubscribe", [*subscriptionID], &block
      self
    end

    # Send mining.notify notification
    # args are : job_id, prevhash, coinb1, coinb2, merkle_branch, version, nbits, ntime, clean_jobs
    def notify *args
      raise ArgumentError, "Wrong number of arguments : #{args.size}" if args.size != 9
      @handler.send_notification "mining.notify", args
      @last_notify_sended = args
      self
    end

    # Send mining.set_difficulty notification
    def set_difficulty diff
      diff = (diff.to_f * 2**16).round# if @handler.type && @handler.type.first =~ /cgminer/i
      @handler.send_notification "mining.set_difficulty", [diff]
      @last_difficulty_sended = diff
      self
    end
  end # class MiningClient
end # module Stratum
