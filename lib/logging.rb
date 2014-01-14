require "logger"

class Logging
  class << self
    attr_writer :logger
    def logger
      @logger ||= Logging.create_logger("git_notebook", Logger::INFO)
    end
  end

  def self.create_logger(file_name_or_stream, level = Logger::INFO)
    if file_name_or_stream.is_a? String
      if file_name_or_stream.include?("/")
        raise "The file name you pass to Logging.create_logger should be just a file name, not a full path."
      end
      unless file_name_or_stream.end_with?(".log")
        file_name_or_stream = "#{file_name_or_stream}.log"
      end
      logger = Logger.new( File.join( GIT_NOTEBOOK_ROOT, "log", file_name_or_stream ) )
    else
      logger = Logger.new( file_name_or_stream )
    end

    logger.formatter = proc do |severity, datetime, program_name, message|
      time = datetime.strftime "%Y-%m-%d %H:%M:%S"
      "[#{time}] #{severity}: #{message}\n"
    end
    logger.level = level
    logger
  end
end
