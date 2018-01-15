module Bosh::AzureCloud
  class Telemetry
    def initialize(operation)
      @logger = Bosh::Clouds::Config.logger
      @operation = operation
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
          },
          {
            "name" => "IsInternal",
            "value" => false
          },
          {
            "name" => "Operation",
            "value" => @operation
          },
          {
            "name" => "ExtensionType",
            "value" => ""
          }
        ]
      }
      # location
      # vm size
      # disk size
      # environment
    end

    def with_telemetry
      event_param_operation_success = {"name" => "OperationSuccess", "value" => true}
      event_param_message = {"name" => "Message", "value" => "Successed"}
      event_param_duration = {"name" => "Duration", "value" => 0}

      start_at = Time.now
      begin
        yield
      rescue => e
        event_param_operation_success["value"] = false
        message = "#{e.inspect}\n#{e.backtrace.join("\n")}"
        message = message[0...3990] + '...' if message.length > 3993 #limit the message to less than 3.9 kB
        event_param_message["value"] = message
        raise e
      ensure
        end_at = Time.now
        event_param_duration["value"] = (end_at - start_at) * 1000.0
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
