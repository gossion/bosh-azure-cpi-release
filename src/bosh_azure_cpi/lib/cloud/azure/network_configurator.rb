module Bosh::AzureCloud
  ##
  # Represents Azure instance network config.
  # According to description on https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-sizes/,
  # an Azure VM can have up to 10 NICs depending on different VM size and VM type;
  # (optionally) Azure cloud service has a single public IP address (vip).
  #


  class NetworkConfigurator
    include Helpers

    attr_reader :vip_network, :networks
    attr_accessor :logger

    ##
    # Creates new network spec
    #
    # @param [Hash] spec raw network spec passed by director
    def initialize(spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, " \
                             "`#{spec.class}' provided"
      end

      @logger = Bosh::Clouds::Config.logger
      @networks = []
      @vip_network = nil
      @networks_spec = spec

      logger.debug ("networks: `#{spec}'")
      network_number = 0
      spec.each_pair do |name, network_spec|
        network_type = network_spec["type"] || "manual"

        case network_type
          when "dynamic"
            @networks << DynamicNetwork.new(name, network_spec)

          when "manual"
            @networks << ManualNetwork.new(name, network_spec)

          when "vip"
            cloud_error("More than one vip network for `#{name}'") if @vip_network
            @vip_network = VipNetwork.new(name, network_spec)

          else
            cloud_error("Invalid network type `#{network_type}' for Azure, " \
                        "can only handle `dynamic', `vip', or `manual' network types")
        end
      end

      if @networks.empty?
        cloud_error("At least one dynamic or manual network must be defined")
      end

    end

    def default_dns
      dns = nil
      @networks.each do |network|
        unless network.cloud_properties.nil? || network.cloud_properties["default"].nil?
          if network.cloud_properties["default"].include? "dns"
            dns = network.cloud_properties["dns"] unless network.cloud_properties["dns"].nil?
          end
        end
      end
      dns
    end

  end
end
