module Bosh::AzureCloud
  class TelemetryEventParam
    attr_writer :value

    PARAM_XML_FORMAT = "<Param Name=\"%{name}\" Value=%{value} T=\"%{type}\" />"

    def initialize(name, value)
      @name = name
      @value = value
    end

    def self.parse_hash(hash)
      new(hash["name"], hash["value"])
    end

    def to_hash
      {"name" => @name, "value" => @value}
    end

    def to_json
      to_hash.to_json
    end

    def to_xml
      value = @value.is_a?(Hash) ? @value.to_json : @value
      PARAM_XML_FORMAT % {:name => @name, :value => value.to_s.encode(:xml => :attr), :type => type_of(@value)}
    end

    private

    def type_of(value)
      case value
      when String
        "mt:wstr"
      when Integer
        "mt:uint64"
      when Float
        "mt:uint64"
      when TrueClass
        "mt:bool"
      when FalseClass
        "mt:bool"
      when Hash
        "mt:wstr"
      else
        "mt:wstr"
      end
    end
  end

  # example:
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
  # allowed parameters:
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
  #
  class TelemetryEvent
    attr_reader :event_id, :provider_id, :parameters

    EVENT_XML_FORMAT = "<Provider id=\"%{provider_id}\"><Event id=\"%{event_id}\"><![CDATA[%{params_xml}]]></Event></Provider>"
    EVENT_XML_WITHOUT_PROVIDER_FORMAT =  "<Event id=\"%{event_id}\"><![CDATA[%{params_xml}]]></Event>"

    def initialize(event_id, provider_id, parameters: [])
      @event_id = event_id
      @provider_id = provider_id
      @parameters = parameters
    end

    def self.parse_hash(hash)
      parameters = []
      hash["parameters"].each do |p|
        parameters.push(TelemetryEventParam.parse_hash(p))
      end
      new(hash["eventId"], hash["providerId"], parameters: parameters)
    end

    def add_param(parameter)
      if  parameter.is_a?(TelemetryEventParam)
        @parameters.push(parameter)
      else
        # do nothing and drop the param
      end
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

    def to_json
      to_hash.to_json
    end

    def to_xml
      params_xml = ""
      @parameters.each do |param|
        params_xml += param.to_xml
      end
      EVENT_XML_FORMAT % {:provider_id => @provider_id, :event_id => @event_id, :params_xml => params_xml}
    end

    # this function is only used in TelemetryEventList which will group the events by provider_id
    def to_xml_without_provider
      params_xml = ""
      @parameters.each do |param|
        params_xml += param.to_xml
      end
      EVENT_XML_WITHOUT_PROVIDER_FORMAT % {:event_id => @event_id, :params_xml => params_xml}
    end
  end

  class TelemetryEventList
    TELEMETRY_XML_FORMAT = "<?xml version=\"1.0\"?><TelemetryData version=\"1.0\">%{events_string}</TelemetryData>"

    def initialize(event_list)
      @event_list = event_list
    end

    def format_data_for_wire_server
      TELEMETRY_XML_FORMAT % {:events_string => to_xml}
    end

    private

    def to_xml
      # group the events by provider id
      events_grouped_by_provider = {}
      @event_list.each do |event|
        events_grouped_by_provider[event.provider_id] = [] unless events_grouped_by_provider.has_key?(event.provider_id)
        events_grouped_by_provider[event.provider_id] << event
      end

      xml_string_grouped_by_providers = ""
      events_grouped_by_provider.keys.each do |provider_id|
        xml_string = ""
        events_grouped_by_provider[provider_id].each do |event|
          xml_string += event.to_xml_without_provider
        end
        xml_string_grouped_by_providers += "<Provider id=\"#{provider_id}\">#{xml_string}</Provider>"
      end
      xml_string_grouped_by_providers
    end
  end
end
