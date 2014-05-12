module Beaker
  module Shared
    module ErrorHandler

    def report_and_raise(logger, e, msg)
      logger.error "Failed: errored in #{msg}"
      logger.error(e.inspect)
      bt = e.backtrace
      logger.pretty_backtrace(bt).each_line do |line|
        logger.error(line)
      end
      raise e
    end

    end
  end
end
