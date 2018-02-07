module Bosh::AzureCloud
  class TelemetryEventHandler
    include Helpers

    COOLDOWN = 60 # seconds

    def initialize(logger)
      @logger = logger
      @wire_client = Bosh::AzureCloud::WireClient.new(logger)
    end

    # Collect events and send them to wireserver
    # Only one instance is allow to process the events at the same time.
    # Once this function get the lock, the instance will be responsible to handle all
    # existed event logs generated prior to and during the time when it hanles the events;
    # Other instances won't get the lock and quit silently, their events will be handled
    # by the instance who got the lock.
    # 
    def collect_and_send_events
      mutex = FileMutex.new(CPI_LOCK_EVENT_HANDLER, @logger)
      begin
        if mutex.lock
          while has_event?() do
            last_post_timestamp = get_last_post_timestamp()
            unless last_post_timestamp.nil?
              duration = Time.now() - last_post_timestamp
              # will only send events once per minute
              if duration > 0  && duration < COOLDOWN
                sleep(COOLDOWN - duration)
              end
            end

            # sent_events
            event_list = collect_events()
            send_events(event_list)
            update_last_post_timestamp(Time.now)
          end
          mutex.unlock
        else
          # quit silently
        end
      rescue => e
        @logger.warn("[Telemetry] Failed to collect and send events. Error:\n#{e.inspect}\n#{e.backtrace.join("\n")}")
        mark_deleting_locks
      end
    end

    private

    def init_sysinfo()
    end

    # Check if there are events to be sent
    def has_event?()
      event_files = Dir["#{CPI_EVENTS_DIR}/*.tld"]
      !event_files.empty?()
    end

    # Collect telemetry events
    #
    # @params [Integer]  max - max event number to collect
    # @return [TelemetryEventList]
    #
    def collect_events(max = 5)
      event_list = []
      event_files = Dir["#{CPI_EVENTS_DIR}/*.tld"]
      event_files = event_files[0...max] if event_files.length > max
      event_files.each do |file|
        hash = JSON.parse(File.read(file))
        event_list << Bosh::AzureCloud::TelemetryEvent.parse_hash(hash)
        File.delete(file)
      end
      Bosh::AzureCloud::TelemetryEventList.new(event_list)
    end

    # Send the events to wireserver
    #
    # @params [TelemetryEventList] event_list - events to be sent
    #
    def send_events(event_list)
      filename = "/tmp/cpi-event-my-event-data"
      File.open(filename, 'w') do |file|
        file.write(event_list.format_data_for_wire_server)
      end
      @wire_client.post_data(event_list.format_data_for_wire_server)
    end

    def get_last_post_timestamp()
      #TODO: remove if failed to parse
      ignore_exception do
        Time.parse(File.read(CPI_EVENT_HANDLER_LAST_POST_TIMESTAMP))
      end
    end

    def update_last_post_timestamp(time)
      File.open(CPI_EVENT_HANDLER_LAST_POST_TIMESTAMP, 'w') do |file|
        file.write(time.to_s)
      end
    end
  end
end
