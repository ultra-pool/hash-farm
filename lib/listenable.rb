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
  
  # Emit signal with some args.
  # self.emit "signal", :with, ["some", "args"]
  def emit(signal, *args)
    @listenable ||= {}
    @listenable[signal] ||= []
    @listenable[signal].each { |m| m.call( *args ) }
  end

  # Call it with a block,
  #   listenableObj.on( signal ) do |*args|
  #     puts args
  #   end
  # with a method, a lambda or a proc,
  #   listenableObj.on( signal, -> { |msg| log(msg) } )
  #   listenableObj.on( signal, myObj.method(:callback) )
  # or with an object and a method to call on this object.
  #   listenableObj.on( signal, myObj, :callback )
  def on(signal, *args, &block)
    @listenable ||= {}
    @listenable[signal] ||= []
    @listenable[signal] << listener_callback(*args, &block)
  end

  # obj.unbind(self)
  # obj.unbind(self, 'signal')
  def off(obj, signal=nil)
    if signal
      signals = [signal]
    else
      signals = @listenable.keys
    end
    signals.each do |s|
      @listenable[s].delete_if do |callback|
        callback.binding.eval("self") == obj
      end
    end
  end

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
