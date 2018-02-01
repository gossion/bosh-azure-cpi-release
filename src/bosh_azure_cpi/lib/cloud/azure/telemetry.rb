module Bosh::AzureCloud
  class Telemetry
    include Helpers

    def initialize(operation)#, subscription_id: nil, vm_size: nil, disk_size: nil)
      @logger = Bosh::Clouds::Config.logger
      @operation = operation
      #@subscription_id = subscription_id #is this a sensitive info?
      #@vm_size = vm_size
      #@disk_size = disk_size

      # parameters:
      #   "Name": "BOSH-CPI"
      #   "Version": ""
      #   "Operation": CPI callback, e.g. create_vm, create_disk, attach_disk, etc
      #   "OperationSuccess": true / false
      #   "Duration": time
      #   "Message": A JSON string contains info of
      #      "msg": "Successed" or error message
      #      "vm_size": vm size or nil
      #      "disk_size": disk size or nil
      #      "subscription_id": subscription id or nil
      #@event = {
      #  "eventId" => 1,
      #  "providerId" => "69B669B9-4AF8-4C50-BDC4-6006FA76E975",
      #  "parameters" => [
      #    {
      #      "name" => "Name",
      #      "value" => "BOSH-CPI"
      #    },
      #    {
      #      "name" => "Version",
      #      "value" => ""
      #    }
      #  ]
      #}
      name_param = TelemetryEventParam.new("Name", "BOSH-CPI")
      version_param = TelemetryEventParam.new("Version", "")
      @event = TelemetryEvent.new("1", "69B669B9-4AF8-4C50-BDC4-6006FA76E975")
      @event.add_param(name_param)
      @event.add_param(version_param)
    end

    # extras:
    #   {"vm_size" => "Standard_D1"}
    #   {"disk_size" => 1024}
    def monitor(extras = {})
      event_param_operation = {"name" => "Operation", "value" => @operation}
      event_param_operation_success = {"name" => "OperationSuccess", "value" => true}
      event_param_duration = {"name" => "Duration"}
      event_param_message = {"name" => "Message"}

      message_value = {"msg" => "Successed"}
      message_value.merge!(extras)
      #message_value["subscription_id"] = @subscription_id unless @subscription_id.nil?
      #message_value["vm_size"] = @vm_size unless @vm_size.nil?
      #message_value["disk_size"] = @disk_size unless @disk_size.nil?

      start_at = Time.now
      begin
        yield
      rescue => e
        event_param_operation_success["value"] = false
        message = "#{e.inspect}\n#{e.backtrace.join("\n")}"
        message = message[0...3990] + '...' if message.length > 3993 #limit the message to less than 3.9 kB
        message_value["msg"] = message
        raise e
      ensure
        end_at = Time.now
        event_param_duration["value"] = (end_at - start_at) * 1000.0
        event_param_message["value"] = message_value.to_json
        @event.add_param(TelemetryEventParam.parse_hash(event_param_operation))
        @event.add_param(TelemetryEventParam.parse_hash(event_param_operation_success))
        @event.add_param(TelemetryEventParam.parse_hash(event_param_message))
        @event.add_param(TelemetryEventParam.parse_hash(event_param_duration))
        report_event()
      end
    end

    private

    def report_event
      begin
        filename = "/tmp/cpi-event-#{SecureRandom.uuid}.tld"
        File.open(filename, 'w') do |file|
          file.write(@event.to_json_string)
        end
        stdout, stderr, status = Open3.capture3("mv #{filename} #{CPI_EVENTS_DIR}")
        #if status != 0
        #log error
        pid = fork {
          TelemetryEventHandler.new().collect_and_send_events()
        }
        Process.detach(pid)
      rescue => e
        @logger.warn("Failed to report event.Error:\n#{e.inspect}\n#{e.backtrace.join("\n")}")
      end
    end
  end


  class TelemetryEventParam
    def initialize(name, value)
      @name = name
      @value = value
      @type = case value.class
              when String
                "mt:wstr"
              when Fixnum
                "mt:uint64"
              when Float
              when TrueClass
              when FalseClass
              end
    end

    def to_hash
      {"name" => @name, "value" => value}
    end

    def self.parse_hash(hash)
      new(hash["name"], hash["value"])
    end

    def to_json_string
      to_hash.to_json.to_s
    end

    def to_xml_string
      "<Param Name=\"#{@name}\" Value=\"#{@value}\" T=\"#{@type}\" />"
    end
  end

  class TelemetryEvent
    def initialize(event_id, provider_id, parameters: [])
      @event_id = event_id
      @provider_id = provider_id
      raise 'error' if !parameters.is_a(Array)
      @parameters = parameters
    end

    def add_param(parameter)
      @parameters.push(parameter) 
    end

    def parse(event_string)
    end

    def to_hash
      parameters = []
      @parameters.each do |p|
        parameters.push(p.to_hash)
      end

      {
        "eventId" => @event_id,
        "providerId" => @provider_id,
        "parameters" => parameters
      }
    end

    def self.parse_hash(hash)
      parameters = []
      hash["parameters"].each do |p|
        parameters.push(TelemetryEventParam.parse_hash(p))
      end
      new(hash["eventId"], hash["providerId"], parameters)
    end

    def to_json_string
      to_hash.to_json.to_s
    end

    def to_xml_string
      #'<?xml version="1.0"?><TelemetryData version="1.0"><Provider id="69B669B9-4AF8-4C50-BDC4-6006FA76E975"><Event id="1"><![CDATA[<Param Name="Name" Value="BOSH-CPI" T="mt:wstr" /><Param Name="Version" Value="" T="mt:wstr" /><Param Name="Operation" Value="initialize" T="mt:wstr" /><Param Name="OperationSuccess" Value="True" T="mt:bool" /><Param Name="Message" Value='{"msg":"Successed"}' T="mt:wstr" /><Param Name="Duration" Value="510.046195" T="mt:float64" /><Param Name="OSVersion" Value="Linux:ubuntu-14.04-trusty:4.4.0-53-generic" T="mt:wstr" /><Param Name="GAVersion" Value="WALinuxAgent-2.1.3" T="mt:wstr" /><Param Name="RAM" Value="6958" T="mt:uint64" /><Param Name="Processors" Value="2" T="mt:uint64" /><Param Name="VMName" Value="_b9c3354c-3275-4049-680f-3748ad0af496" T="mt:wstr" /><Param Name="TenantName" Value="8c1b2d76-a666-4958-a7ec-6ef464422ad1" T="mt:wstr" /><Param Name="RoleName" Value="_b9c3354c-3275-4049-680f-3748ad0af496" T="mt:wstr" /><Param Name="RoleInstanceName" Value="8c1b2d76-a666-4958-a7ec-6ef464422ad1._b9c3354c-3275-4049-680f-3748ad0af496" T="mt:wstr" /><Param Name="ContainerId" Value="edf9b1e3-90dd-4da5-9c23-6c9a2f419ddc" T="mt:wstr" />]]></Event></Provider></TelemetryData>'
      
      params_xml = ""
      @parameters.each do |param|
        params_xml += param.to_s
      end
      "<Provider id=\"#{@provider_id}\"><Event id=\"#{@event_id}\"><![CDATA[#{params_xml}]]></Event></Provider>"
    end
  end

  class TelemetryEventHandler
    include Helpers

    def initialize(logger)
      @logger = logger
      @event_list = []
    end

    def init_sysinfo()
    end

    # params
    #   max - max event number to collect
    # return bool
    #   true  - has events 
    #   false - no event
    def collect_events(max = 5)
      event_files = Dir["#CPI_EVENTS_DIR/*.tld"]
      event_files = event_files[0...max] if event_files.length > max
      event_files.each do |file|
        @event_list << TelemetryEvent.parse(File.read(file))
      end
      return !event_files.empty?()
    end

    def send_events()
      event_lists_xml = ""
      @event_list.each do |event|
        event_lists_xml += event.to_s
      end
      WireClient.new().send_events(event_lists_xml) unless event_lists_xml.empty?()
    end

    def collect_and_send_events
      mutex = FileMutex.new({CPI_LOCK_EVENT_HANDLER, @logger)
      begin
        if mutex.lock
          while collect_events() do
            # check last update
            last_post_timestamp = get_last_post_timestamp()
            # sleep related time
            unless last_post_timestamp.nil?
              duration = Time.now() - last_post_timestamp
              if duration > 0  && duration < 60
                # will only send once per minute
                sleep(60 - duration)
              end
            end
            # sent_events
            send_events()
          end
          mutex.unlock
        else
          # do nothing
        end
      rescue => e
        mark_deleting_locks
      end
    end

    def get_last_post_timestamp()
      ignore_exception do
        Time.parse(File.read(CPI_EVENT_HANDLER_LAST_POST_TIMESTAMP))
      end
    end

    def update_last_post_timestamp(time)
      ignore_exception do
        File.open(CPI_EVENT_HANDLER_LAST_POST_TIMESTAMP, 'w') do |file|
          file.write(time.to_s)
        end
      end
    end
  end
end
