module Bosh::AzureCloud
  class CPILogger
    def self.get_logger(device)
      Logging.appenders.stdout(
        :layout => Logging.layouts.pattern(
        :pattern =>  "%.1l, [%d #%p #%t] %l --%X{flag}: %m\n", # flag is a placeholder for request id
        :date_pattern  => '%Y-%m-%dT%H:%M:%S.%6N'
        )
      )

      logger = Logging.logger['CPI']
      logger.add_appenders 'stdout'
      logger.level = :debug
      logger
    end

    def self.set_request_id(id)
      Logging.mdc['flag'] = " [req_id #{id}]"
    end
  end
end
