module Bosh::AzureCloud
  class WireClient

    TELEMETRY_URI = "http://%{endpoint}/machine?comp=telemetrydata"
    TELEMETRY_FORMAT = "<?xml version=\"1.0\"?>
                        <TelemetryData version=\"1.0\">
                        %{events_string}
                        </TelemetryData>"
    #TELEMETRY_HEADER = {'Content-Type': 'text/xml;charset=utf-8', 'x-ms-version': '2012-11-30', 'x-ms-agent-name': 'WALinuxAgent'}


    HEADER_LEASE = "lease {"
    HEADER_OPTION = "option unknown-245"
    HEADER_DNS = "option domain-name-servers"
    HEADER_EXPIRE = "expire"
    FOOTER_LEASE = "}"

    def initialize()
      @distro = "ubuntu"
      #ubuntu
      leases_path = '/var/lib/dhcp/dhclient.*.leases'
      #centos
      leases_path = '/var/lib/dhclient/dhclient-*.leases'
      @endpoint = get_endpoint_from_leases_path(leases_path)
    end

    #
    #  Try to discover and decode the wireserver endpoint in the
    #  specified dhcp leases path.
    #  :param pathglob: The path containing dhcp lease files
    #  :return: The endpoint if available, otherwise nil
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
          when /"#{HEADER_LEASE}"/
            is_lease_file = true
          when /"#{HEADER_OPTION}"/
            #example - option unknown-245 a8:3f:81:10;
            endpoint = get_ip_from_lease_value(line.gsub!(HEADER_OPTION, '').gsub!(';', '').strip)
          when /"#{HEADER_EXPIRE}"/
            # example - expire 1 2018/01/29 04:45:46;
            if line.include?("never")
              expired = false
            else
              begin
                ret = line.match('.*expire (\d*) (.*);')
                expire_date = ret[2] #
                expired = false if expire_date > Time.now()
              rescue
              end
            end
          when /#{FOOTER_LEASE}/
            return endpoint if !endpoint.nil? && !expired
          end
        end
      end

      logger.warn("Can't find endpoint from leases_path #{leases_path}")
    end

    def send_events(event_list_string)
      #https://github.com/Azure/WALinuxAgent/blob/f52a9a546d9005ad15ec1af47aeaa46169374dbf/azurelinuxagent/common/protocol/wire.py#L1004
      uri = TELEMETRY_URI % {:endpoint => @endpoint}
      data = TELEMETRY_FORMAT % {:events_string => event_list_string}

      unless @endpoint.nil?
        begin
          post_xml(uir, data, TELEMETRY_HEADER)
        rescue => e
          #retry
        end
      end
    end

    def post_xml url_string, xml_string
      uri = URI.parse url_string
      request = Net::HTTP::Post.new uri.path
      request.body = xml_string
      request.content_type = 'text/xml'
      response = Net::HTTP.new(uri.host, uri.port).start { |http| http.request request }
      response.body

      #header = {header part}
      #data = {"a"=> "123"}
      #uri = URI.parse("https://anyurl.com")
      #https = Net::HTTP.new(uri.host,uri.port)
      #https.use_ssl = true
      #req = Net::HTTP::Post.new(uri.path, header)
      #req.body = data.to_json
      #res = https.request(req)
      #
      #puts "Response #{res.code} #{res.message}: #{res.body}"
    end

    private

    def get_ip_from_lease_value(fallback_lease_value)
      #https://www.ruby-forum.com/topic/58191
      unescaped_value = fallback_lease_value.gsub!('\\', '')
      if unescaped_value.length > 4
        unescaped_value.split(":").map{|c| c.hex}.join('.')
      else
        #unknown value
      end
    end
  end
end
