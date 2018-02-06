module Bosh::AzureCloud
  class Telemetry
    include Helpers

    EVENT_ID = "1"
    PROVIDER_ID = "69B669B9-4AF8-4C50-BDC4-6006FA76E975"
    CPI_TELEMETRY_NAME = "BOSH-CPI"

    def initialize(azure_properties, logger, operation)
      @azure_properties = azure_properties
      @logger = logger

      event_param_name = Bosh::AzureCloud::TelemetryEventParam.new("Name", CPI_TELEMETRY_NAME)
      #TODO: get version
      event_param_version = Bosh::AzureCloud::TelemetryEventParam.new("Version", "")
      event_param_operation = Bosh::AzureCloud::TelemetryEventParam.new("Operation", operation)
      
      @event = Bosh::AzureCloud::TelemetryEvent.new(EVENT_ID, PROVIDER_ID)
      @event.add_param(event_param_name)
      @event.add_param(event_param_version)
      @event.add_param(event_param_operation)
    end

    # Monitor the status of a block
    # @param [Hash] extras - Extra values passed by individual function. The values will be merged to 'message' column of the event.
    #                        Example:  {"instance_type" => "Standard_D1"}
    # @return - return value of the block
    #
    def monitor(extras = {})
      event_param_operation_success = Bosh::AzureCloud::TelemetryEventParam.new("OperationSuccess", true)
      event_param_message = Bosh::AzureCloud::TelemetryEventParam.new("Message", "")
      event_param_duration = Bosh::AzureCloud::TelemetryEventParam.new("Duration", 0)

      message_value = {
        "msg" => "Successed",
        "subscription_id" => @azure_properties['subscription_id']
      }

      ignore_exception do
        message_value.merge!(extras)
      end

      start_at = Time.now
      begin
        yield
      rescue => e
        event_param_operation_success.value = false
        msg = "#{e.inspect}\n#{e.backtrace.join("\n")}"
        msg = msg[0...3990] + '...' if msg.length > 3993 # limit the message to less than 3.9 kB
        message_value["msg"] = msg
        raise e
      ensure
        end_at = Time.now
        event_param_duration.value = (end_at - start_at) * 1000.0 # miliseconds
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
        Dir.mkdir(CPI_EVENTS_DIR) unless File.exists?(CPI_EVENTS_DIR)
        stdout, stderr, status = Open3.capture3("mv #{filename} #{CPI_EVENTS_DIR}")
        if status != 0
          logger.warn("[Telemetry] Failed to move #{filename} to #{CPI_EVENTS_DIR}, error: #{stderr}")
        else
          # trigger event handler to send the event
          pid = fork {
            Bosh::AzureCloud::TelemetryEventHandler.new(@logger).collect_and_send_events()
          }
          Process.detach(pid)
        end
      rescue => e
        @logger.warn("[Telemetry] Failed to report event. Error:\n#{e.inspect}\n#{e.backtrace.join("\n")}")
      end
    end
  end
end
