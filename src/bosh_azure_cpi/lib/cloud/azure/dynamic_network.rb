module Bosh::AzureCloud

  class DynamicNetwork < Network
    include Helpers

    attr_reader :virtual_network_name, :subnet_name, :security_group

    # create dynamic network
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super

      if @cloud_properties.nil?
        cloud_error("cloud_properties required for dynamic network")
      end

      @security_group = @cloud_properties["security_group"]

      unless @cloud_properties["virtual_network_name"].nil?
        @virtual_network_name = @cloud_properties["virtual_network_name"]
      else
        cloud_error("virtual_network_name required for dynamic network")
      end

      unless @cloud_properties["subnet_name"].nil?
        @subnet_name = @cloud_properties["subnet_name"]
      else
        cloud_error("subnet_name required for dynamic network")
      end
    end

  end
end
