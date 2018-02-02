module Bosh::AzureCloud
  class TelemetryEventParam
    attr_reader :name
    attr_accessor :value

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

  class TelemetryEventList
    def initialize(event_list)
      @event_list = event_list
    end

    def to_xml_string
      #sort

      @event_list.each do |event|
      
      end
    end
  end
end
