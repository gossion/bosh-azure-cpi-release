module Bosh::AzureCloud
  class WireClient
    attr_reader :endpoint

    TELEMETRY_URI_FORMAT = "http://%{endpoint}/machine?comp=telemetrydata"
    TELEMETRY_HEADER = {'Content-Type' => 'text/xml;charset=utf-8', 'x-ms-version' => '2012-11-30', 'x-ms-agent-name' => 'WALinuxAgent'}

    HEADER_LEASE = "lease {"
    HEADER_OPTION = "option unknown-245"
    HEADER_DNS = "option domain-name-servers"
    HEADER_EXPIRE = "expire"
    FOOTER_LEASE = "}"

    LEASE_PATHS = {
      'Ubuntu' => '/var/lib/dhcp/dhclient.*.leases',
      'Centos' => '/var/lib/dhclient/dhclient-*.leases',
      nil      => '/var/lib/dhcp/dhclient.*.leases'
    }

    def initialize(logger)
      @logger = logger
      @endpoint = get_endpoint()
    end

    def post_data(event_data)
      #https://github.com/Azure/WALinuxAgent/blob/f52a9a546d9005ad15ec1af47aeaa46169374dbf/azurelinuxagent/common/protocol/wire.py#L1004
      unless @endpoint.nil?
        uri = URI.parse(TELEMETRY_URI_FORMAT % {:endpoint => @endpoint})
        begin
          @logger.debug("YYYYYYYYY. event_data: #{event_data}, TELEMETRY_HEADER: #{TELEMETRY_HEADER}")
          #res = Net::HTTP.post(uri, event_data, TELEMETRY_HEADER)
          request = Net::HTTP::Post.new uri.path
          request.body = event_data
          request.content_type = 'text/xml;charset=utf-8'
          request['x-ms-version'] = '2012-11-30'
          request['x-ms-agent-name'] = 'WALinuxAgent'
          res = Net::HTTP.new(uri.host, uri.port).start { |http| http.request request }
          @logger.debug("XXXXXXXXXXXXXXXXXXres: #{res.code}, #{res.body}, \n INSPECT: #{res.inspect}}")
        rescue => e
          #retry
          @logger.warn("[Telemetry] Failed to post data to uri #{uri}. Error: \n#{e.inspect}\n#{e.backtrace.join("\n")}")
        end
      else
        @logger.warn("[Telemetry] Wire server endpoint is nil, drop data")
      end
    end

    private

    def get_endpoint()
      # detect os
      os = nil
      if File.exists?("/etc/lsb-release")
        os = "Ubuntu" if File.read("/etc/lsb-release").include?("Ubuntu")
      else
        # TODO: for CentOS
      end

      get_endpoint_from_leases_path(LEASE_PATHS[os])
    end

    #
    # Try to discover and decode the wireserver endpoint in the
    # specified dhcp leases path.
    # @param [String] leases_path -  The path containing dhcp lease files
    # @return [String]            -  The endpoint if available, otherwise nil
    #
    def get_endpoint_from_leases_path(leases_path)
      #https://github.com/Azure/WALinuxAgent/blob/8c38bd6c7aa367e9d077ef454a0f96cdb1dd7bb7/azurelinuxagent/common/osutil/default.py#L806
      #https://github.com/number5/cloud-init/blob/master/cloudinit/sources/helpers/azure.py#L248
      lease_files = Dir[leases_path]
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

    def post_xml(xml_string)
      #uri = URI.parse url_string
      #request = Net::HTTP::Post.new uri.path
      #request.body = xml_string
      #request.content_type = 'text/xml'
      #response = Net::HTTP.new(uri.host, uri.port).start { |http| http.request request }
      #response.body

      #https = Net::HTTP.new(uri.host,uri.port)
      #https.use_ssl = true
      #req = Net::HTTP::Post.new(uri.path, header)
      #req.body = data.to_json
      #res = https.request(req)
      #
      #puts "Response #{res.code} #{res.message}: #{res.body}"

      # TODO: retry
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
