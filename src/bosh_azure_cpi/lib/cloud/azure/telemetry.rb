module Bosh::AzureCloud
  class Telemetry
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
      @event = {
        "eventId" => 1,
        "providerId" => "69B669B9-4AF8-4C50-BDC4-6006FA76E975",
        "parameters" => [
          {
            "name" => "Name",
            "value" => "BOSH-CPI"
          },
          {
            "name" => "Version",
            "value" => ""
          }
        ]
      }
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
        @event["parameters"] << event_param_operation
        @event["parameters"] << event_param_operation_success
        @event["parameters"] << event_param_message
        @event["parameters"] << event_param_duration
        report_event()
      end
    end

    private

    def report_event
      begin
        filename = "/tmp/cpi-event-#{SecureRandom.uuid}.tld"
        File.open(filename, 'w') do |file|
          file.write(@event.to_json)
        end
        system("sudo mv #{filename} /var/lib/waagent/events/")
      rescue => e
        @logger.warn("Failed to report event.Error:\n#{e.inspect}\n#{e.backtrace.join("\n")}")
      end
    end
  end
end
