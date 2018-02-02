module Bosh::AzureCloud
  class Telemetry
    EVENT_ID = "1"
    PROVIDER_ID = "69B669B9-4AF8-4C50-BDC4-6006FA76E975"
    CPI_TELEMETRY_NAME = "BOSH-CPI"

    def initialize(azure_properties, logger, operation)
      @azure_properties = azure_properties
      @logger = logger

      event_param_name = TelemetryEventParam.new("Name", CPI_TELEMETRY_NAME)
      #TODO: get version
      event_param_version = TelemetryEventParam.new("Version", "")
      event_param_operation = TelemetryEventParam.new("Operation", operation)
      
      @event = TelemetryEvent.new(EVENT_ID, PROVIDER_ID)
      @event.add_param(event_param_name)
      @event.add_param(event_param_version)
      @event.add_param(event_param_operation)
    end

    # Monitor the status of a block
    # @param [Hash] extras - Extra values passed by individual function. The values will be merged to 'message' column.
    #                        For example, if you want to record instance_type when creating the VM: {"instance_type" => "Standard_D1"}
    # @return - return value of the block
    #
    def monitor(extras = {})
      event_param_operation_success = TelemetryEvent.new("OperationSuccess", true)
      event_param_duration = TelemetryEvent.new("Duration", 0)
      event_param_message = TelemetryEvent.new("Message", "")

      message_value = {
        "msg" => "Successed",
        "subscription_id" => @azure_properties['subscription_id']
      }
      message_value.merge!(extras)

      start_at = Time.now
      begin
        yield
      rescue => e
        event_param_operation_success.value = false
        message = "#{e.inspect}\n#{e.backtrace.join("\n")}"
        message = message[0...3990] + '...' if message.length > 3993 #limit the message to less than 3.9 kB
        message_value["msg"] = message
        raise e
      ensure
        end_at = Time.now
        event_param_duration.value = (end_at - start_at) * 1000.0
        event_param_message.value = message_value.to_json.to_s

        @event.add_param(event_param_operation_success)
        @event.add_param(event_param_message)
        @event.add_param(event_param_duration)
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
        if status != 0
          logger.warn("Failed to copy #{filename} to #{CPI_EVENTS_DIR}, error: #{stderr}")
        else
          pid = fork {
            TelemetryEventHandler.new(@logger).collect_and_send_events()
          }
          Process.detach(pid)
        end
      rescue => e
        @logger.warn("Failed to report event.Error:\n#{e.inspect}\n#{e.backtrace.join("\n")}")
      end
    end
  end
end
