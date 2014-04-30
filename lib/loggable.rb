# -*- encoding : utf-8 -*-

require 'rails'
require 'log4r'
require 'log4r/configurator'

Log4r::Configurator.custom_levels( "DEBUG", "VERBOSE", "INFO", "WARN", "ERROR" )

module Loggable
  DEFAULT_STDOUT_LEVEL = Log4r::VERBOSE
  PATTERN = Log4r::PatternFormatter.new( pattern: "[%d][%l][%c] %m", date_pattern: "%T" )

  def Loggable.included( aMod )
    id = aMod.name.underscore
    logger = Log4r::Logger.new( id )
    log_filename = "./log/loggers/" + id + ".log"
    `mkdir -p #{File.dirname(log_filename)}`
    file_outputter = Log4r::Outputter["#{id}_file"] || Log4r::FileOutputter.new( "#{id}_file", level: Log4r::DEBUG, filename: log_filename, formatter: PATTERN )
    stdout_outputter = Log4r::Outputter["our_stdout"] || Log4r::StdoutOutputter.new( "our_stdout", level: DEFAULT_STDOUT_LEVEL, formatter: PATTERN )
    logger.outputters = [stdout_outputter, file_outputter]

    aMod.instance_variable_set :@log, logger
    aMod.extend( LogMethods )
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
