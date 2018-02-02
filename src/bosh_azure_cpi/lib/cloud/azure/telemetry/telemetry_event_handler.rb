module Bosh::AzureCloud
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
        event_list << TelemetryEvent.parse(File.read(file))
      end
      @event_list = TelemetryEventList.new(event_list)
      return !event_files.empty?()
    end

    def send_events()
      event_lists_xml = ""
      @event_list.each do |event|
        event_lists_xml += event.to_s
      end
      WireClient.new(@logger).send_events(event_lists_xml) unless event_lists_xml.empty?()
    end

    def collect_and_send_events
      mutex = FileMutex.new(CPI_LOCK_EVENT_HANDLER, @logger)
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
