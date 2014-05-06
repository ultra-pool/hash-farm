# -*- encoding : utf-8 -*-

# include Listenable in your class to allow emit/on signal handling.
# In your Listenable class, call emit("aSignal", :with, :some, :args)
# In your Listener class, call listenableObj.on("aSignal")
module Listenable
  ListenableUsage = <<-USAGE
Usage :
  Listenable.on(signal, aProc)
  Listenable.on(signal, obj, :methodName)
  Listenable.on(signal) do |args|
    do_something(args)
  end
USAGE
  
  # Call it with a block,
  #   listenableObj.on( signal ) do |*args|
  #     puts args
  #   end
  # with a method, a lambda or a proc,
  #   listenableObj.on( signal, -> { |msg| log(msg) } )
  #   listenableObj.on( signal, myObj.method(:callback) )
  # or with an object and a method name to call on this object.
  #   listenableObj.on( signal, myObj, :callback )
  # => a callback_id
  def on(signal, *args, &block)
    @listenable ||= {}
    @listenable[signal] ||= []
    cb = listener_callback(*args, &block)
    @listenable[signal] << cb
    id = "#{signal}:#{cb.object_id}"
  end

  # obj.unbind( callback_id )
  # obj.unbind( self, 'signal' )
  # obj.unbind( self )
  def off(obj, signal=nil)
    if obj.kind_of?( String )
      signal, cb_id = obj.split(':')
      cb_id = cb_id.to_i
      return if ! @listenable[signal]
      @listenable[signal].delete_if do |cb| cb.object_id == cb_id end
    elsif signal
      return if ! @listenable[signal]
      @listenable[signal].delete_if do |callback|
        callback.binding.eval("self") == obj
      end
    else
      @listenable.keys.each do |signal|
        @listenable[signal].delete_if do |callback|
          callback.binding.eval("self") == obj
        end
      end
    end
  end

  protected

    # Emit signal with some args.
    # self.emit "signal", :with, ["some", "args"]
    def emit(signal, *args)
      @listenable ||= {}
      @listenable[signal] ||= []
      @listenable[signal].each { |m| call( m, signal, args ) }
      @listenable[:__all] ||= []
      @listenable[:__all].each { |m| call( m, signal, [signal, *args] ) }
    end

    def call( callback, signal, args )
      callback.call( *args )
    rescue => err
      msg  = "Error on('#{signal}') : #{err}\n"
      msg += "@ #{callback.source_location}\n"
      msg += "With args : #{args.inspect}\n"
      msg += err.backtrace[0...5].join("\n")
      if self.respond_to?( :log )
        log.error msg
      else
        puts "[%s][ERROR][%s] %s" % [Time.now.strftime("%T"), self.class.name.underscore, msg]
      end
    end

    def forward( obj, signal=:__all )
      obj.on( signal ) do |*params|
        # When signal is :__all, the real signal is embedded in given params.
        params.unshift( signal ) unless signal == :__all
        emit( *params )
      end
    end

  private

    def listener_callback(*args, &block)
      if block_given?
        block
      elsif args.size == 1 && args.first.respond_to?( :call )
        args.first.to_proc
      elsif args.size == 2 && args[0].respond_to?( args[1] )
        args[0].method( args[1] ).to_proc
      else
        raise ArgumentError, ListenableUsage
      end
    end
end
