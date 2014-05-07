# -*- encoding : utf-8 -*-

require 'rails'
require 'log4r-color'
require 'log4r-color/configurator'

Log4r::Configurator.custom_levels( "DEBUG", "VERBOSE", "INFO", "WARN", "ERROR" )

module Loggable
  DEFAULT_STDOUT_LEVEL = Log4r::INFO
  PATTERN = Log4r::PatternFormatter.new( pattern: "[%d][%l][%c] %m", date_pattern: "%T" )
  COLORS = {
    debug: :light_blue,
    verbose: :white,
    info: :light_blue,
    warn: :yellow,
    :error => :red,
  }

  def Loggable.included( aMod )
    id = identify( aMod )
    logger = logger( id )
    aMod.instance_variable_set :@log, logger
    aMod.extend( LogMethods )
  end

  def Loggable.logger( id )
    logger = Log4r::Logger[id]
    return logger if logger

    logger = Log4r::Logger.new( id )
    log_filename = "./log/loggers/" + id + ".log"
    `mkdir -p #{File.dirname(log_filename)}`
    file_outputter = Log4r::Outputter["#{id}_file"] || Log4r::FileOutputter.new( "#{id}_file", level: Log4r::DEBUG, filename: log_filename, formatter: PATTERN )
    stdout_outputter = Log4r::Outputter["our_stdout"] || Log4r::ColorOutputter.new( "our_stdout", level: DEFAULT_STDOUT_LEVEL, formatter: PATTERN, colors: COLORS)
    logger.outputters = [stdout_outputter, file_outputter]
    logger
  end

  # Used is test/test_helper
  def Loggable.mute
    Log4r::Logger.global.level = Log4r::OFF
    Log4r::Logger.each_logger { |logger| logger.level = Log4r::OFF }
  end

  # Used is test/test_helper
  def Loggable.unmute
    Log4r::Logger.global.level = Log4r::ALL
    Log4r::Logger.each_logger { |logger| logger.level = Log4r::ALL }
  end

  def Loggable.log( str )
    self.logger( 'default' ).info( str )
  end

  def Loggable.identify( obj )
    if obj.kind_of?( Module )
      obj.name.underscore
    else
      obj.class.name.underscore
    end
  end

  def log
    self.class.log
  end

  module LogMethods
    def log
      @log
    end

    def disable_logs
      @log.level = Log4r::OFF
    end
    alias_method :mute, :disable_logs
  end
end
