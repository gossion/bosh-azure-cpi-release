module Bosh::AzureCloud
  class RetryableLogger
    def initialize(logger)
      @logger = logger
    end

    def debug(progname = nil, &block)
      retryable do
        @logger.debug(progname, &block)
      end
    end

    def info(progname = nil, &block)
      retryable do
        @logger.info(progname, &block)
      end
    end

    def warn(progname = nil, &block)
      retryable do
        @logger.warn(progname, &block)
      end
    end
    def error(progname = nil, &block)
      retryable do
        @logger.error(progname, &block)
      end
    end

    def fatal(progname = nil, &block)
      retryable do
        @logger.fatal(progname, &block)
      end
    end

    def unknown(progname = nil, &block)
      retryable do
        @logger.unknown(progname, &block)
      end
    end

    def set_request_id(req_id)
      @logger.set_request_id(req_id)
    end

    private

    def retryable(options = {})
      opts = { :retries => 2,
               :sleep => 2,
               :ignore_exception => true
             }.merge(options)
      retries = opts[:retries]

      begin
        return yield
      rescue => e
        retries -= 1
        if retries >= 0
          sleep(opts[:sleep])
          retry
        end
        raise e unless opts[:ignore_exception]
      end
    end
  end
end
