module Bosh::AzureCloud
  class RetriableError < Net::HTTPError; end

  class WireClient
    TELEMETRY_URI_FORMAT = "http://%{endpoint}/machine?comp=telemetrydata"
    TELEMETRY_HEADER     = {'Content-Type' => 'text/xml;charset=utf-8', 'x-ms-version' => '2012-11-30', 'x-ms-agent-name' => 'WALinuxAgent'}

    RETRY_ERROR_CODES    = [408, 429, 500, 502, 503, 504]
    SLEEP_BEFORE_RETRY   = 5

    HEADER_LEASE         = "lease {"
    HEADER_OPTION        = "option unknown-245"
    HEADER_DNS           = "option domain-name-servers"
    HEADER_EXPIRE        = "expire"
    FOOTER_LEASE         = "}"

    LEASE_PATHS = {
      'Ubuntu' => '/var/lib/dhcp/dhclient.*.leases',
      'CentOS' => '/var/lib/dhclient/dhclient-*.leases',
    }

    def initialize(logger)
      @logger = logger
    end

    # Post data to wireserver
    #
    # @param [String] event_data - Data formatted as XML string
    #
    def post_data(event_data)
      endpoint = get_endpoint()

      unless endpoint.nil?
        uri = URI.parse(TELEMETRY_URI_FORMAT % {:endpoint => endpoint})
        retried = false
        begin
          request = Net::HTTP::Post.new(uri)
          request.body = event_data
          TELEMETRY_HEADER.keys.each do |key|
            request[key] = TELEMETRY_HEADER[key]
          end
          #res = Net::HTTP.new(uri.host, uri.port).start { |http| http.request request } #TODO: test below change
          res = Net::HTTP.new(uri.host, uri.port, nil).start { |http| http.request request }

          status_code = res.code.to_i
          if status_code == 200
            @logger.debug("[Telemetry] Data posted")
          elsif  RETRY_ERROR_CODES.include?(status_code)
            raise RetriableError, "POST response - code: #{res.code}\nbody:#{res.body}"
          else
            raise "POST response - code: #{res.code}\nbody:#{res.body}"
          end
        rescue RetriableError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET => e
          if !retried
            retried = true
            sleep(SLEEP_BEFORE_RETRY)
            @logger.debug("[Telemetry] Failed to post data, retrying...")
            retry
          else
            @logger.warn("[Telemetry] Failed to post data to uri #{uri}. Error: \n#{e.inspect}\n#{e.backtrace.join("\n")}")
          end
        rescue => e
          @logger.warn("[Telemetry] Failed to post data to uri #{uri}. Error: \n#{e.inspect}\n#{e.backtrace.join("\n")}")
        end
      else
        @logger.warn("[Telemetry] Wire server endpoint is nil, drop data")
      end
    end

    private

    # Get endpoint for different OS, only Ubuntu and CentOS are supported.
    #
    def get_endpoint()
      os = nil
      endpoint = nil
      if File.exists?("/etc/lsb-release")
        os = "Ubuntu" if File.read("/etc/lsb-release").include?("Ubuntu")
      elsif File.exists?("/etc/centos-release")
        os = "CentOS" if File.read("/etc/centos-release").include?("CentOS")
      end
      endpoint = get_endpoint_from_leases_path(LEASE_PATHS[os]) unless os.nil?
      endpoint
    end

    # Try to discover and decode the wireserver endpoint in the specified dhcp leases path.
    #
    # @param [String] leases_path -  The path containing dhcp lease files
    # @return [String]            -  The endpoint if available, otherwise nil
    #
    def get_endpoint_from_leases_path(leases_path)
      lease_files = Dir.glob(leases_path)
      lease_files.each do |file_name|
        is_lease_file = false
        endpoint = nil
        expired  = true

        file = File.open(file_name, 'r')
        file.each_line do |line|
          case line
          when /#{HEADER_LEASE}/
            is_lease_file = true
          when /#{HEADER_OPTION}/
            #example - option unknown-245 a8:3f:81:10;
            endpoint = get_ip_from_lease_value(line.gsub(HEADER_OPTION, '').gsub(';', '').strip)
          when /#{HEADER_EXPIRE}/
            # example - expire 1 2018/01/29 04:45:46;
            if line.include?("never")
              expired = false
            else
              begin
                ret = line.match('.*expire (\d*) (.*);')
                expire_date = ret[2] #
                expired = false if Time.parse(expire_date) > Time.now()
              rescue => e
                logger.warn("[Telemetry] Failed to get expired data for leases of endpoint. Error:\n#{e.inspect}\n#{e.backtrace.join("\n")}")
              end
            end
          when /#{FOOTER_LEASE}/
            return endpoint if is_lease_file && !endpoint.nil? && !expired
          end
        end
      end

      @logger.warn("Can't find endpoint from leases_path #{leases_path}")
      nil
    end

    def get_ip_from_lease_value(fallback_lease_value)
      #https://www.ruby-forum.com/topic/58191
      unescaped_value = fallback_lease_value.gsub('\\', '')
      if unescaped_value.length > 4
        unescaped_value.split(":").map{|c| c.hex}.join('.')
      else
        #unknown value
        nil
      end
    end
  end
end
