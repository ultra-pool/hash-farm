# -*- encoding : utf-8 -*-

require 'log4r'
require 'log4r/configurator'

Log4r::Configurator.custom_levels( "DEBUG", "VERBOSE", "INFO", "WARN", "ERROR" )
#
# To use Loggers, just call Loggers.init_logger( __FILE__ ) at the beginning of the file,
# and call Loggers.get_logger( __FILE__ ) when you want a logger (for each instance for example).
#
# WARNING !
# It is difficult to have a logger per file/class in Ruby, due to inheritance : you inherite and override superclass logger...
#
module Loggers
  include Log4r

  DEFAULT_STDOUT_LEVEL = INFO
  PATTERN = PatternFormatter.new( pattern: "[%l][%d] %c : %m", date_pattern: "%T" )

  @@loggers = {}

  def self.filename_to_id( filename )
    path = Pathname.new( filename )
    `mkdir -p #{path.dirname}`
    path.relative_path_from( Rails.root ).sub(/\.\w+$/, '').to_s
  end

  def self.init_logger( filename, level=nil )
    id = filename_to_id( filename )
    logger = Log4r::Logger.new( id )
    logger.level = level || DEFAULT_STDOUT_LEVEL
    log_filename = "./log/loggers/" + id + ".log"
    file_outputter = FileOutputter.new( '#{id}_file', level: DEBUG, filename: log_filename, formatter: PATTERN )
    logger.outputters = [Outputter.stdout, file_outputter]
    @@loggers[ filename ] = logger
  end

  def self.get_logger( filename )
    @@loggers[ filename ]
  end
end

Log4r::Outputter.stdout.level = Loggers::DEFAULT_STDOUT_LEVEL
Log4r::Outputter.stdout.formatter = Loggers::PATTERN
