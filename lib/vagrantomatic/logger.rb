require "logger"
module Vagrantomatic
  # Logger is a class to allow for stateful and separate logs between instances
  # by passing in individual loggers on initialisation
  class Logger

    def initialize(logger=nil)
      if logger
        @logger = logger
      else
        @logger = ::Logger.new(STDOUT)
      end
    end

    def logger
      @logger
    end
  end
end
