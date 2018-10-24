# frozen_string_literal: true

module Bosh::AzureCloud
  class VMCloudProps
    include Helpers
    attr_reader :resource_group_name, :instance_type
    attr_reader :storage_account_type, :storage_account_kind, :storage_account_max_disk_number, :storage_account_name
    attr_reader :availability_zone
    attr_reader :availability_set
    attr_reader :tags
    attr_reader :caching
    attr_reader :root_disk, :ephemeral_disk
    attr_reader :ip_forwarding, :accelerated_networking, :assign_dynamic_public_ip, :application_gateway
    attr_reader :load_balancer
    attr_reader :application_security_groups
    attr_reader :security_group

    attr_writer :availability_zone
    attr_writer :availability_set
    attr_writer :assign_dynamic_public_ip

    attr_accessor :location

    AVAILABILITY_SET_KEY = 'availability_set'
    LOAD_BALANCER_KEY = 'load_balancer'
    RESOURCE_GROUP_NAME_KEY = 'resource_group_name'
    NAME_KEY = 'name'

    def initialize(vm_properties, global_azure_config)
      @vm_properties = vm_properties.dup

      @instance_type = vm_properties['instance_type']
      @resource_group_name = vm_properties.fetch('resource_group_name', global_azure_config.resource_group_name)
      @storage_account_type = vm_properties['storage_account_type']
      @availability_zone = vm_properties['availability_zone']
      @availability_set = _parse_availability_set_config(vm_properties, global_azure_config)
      @storage_account_name = vm_properties['storage_account_name']
      @storage_account_max_disk_number = vm_properties.fetch('storage_account_max_disk_number', 30)
      @storage_account_kind = vm_properties.fetch('storage_account_kind', STORAGE_ACCOUNT_KIND_GENERAL_PURPOSE_V1)
      @tags = vm_properties.fetch('tags', {})
      @caching = vm_properties.fetch('caching', 'ReadWrite')

      @ip_forwarding = vm_properties['ip_forwarding']
      @accelerated_networking = vm_properties['accelerated_networking']
      @assign_dynamic_public_ip = vm_properties['assign_dynamic_public_ip']

      @load_balancer = _parse_load_balancer_config(vm_properties, global_azure_config)

      @application_gateway = vm_properties['application_gateway']

      @application_security_groups = vm_properties['application_security_groups']
      @security_group = Bosh::AzureCloud::SecurityGroup.parse_security_group(vm_properties['security_group'])

      root_disk_hash = vm_properties.fetch('root_disk', {})
      ephemeral_disk_hash = vm_properties.fetch('ephemeral_disk', {})
      @root_disk = Bosh::AzureCloud::RootDisk.new(root_disk_hash['size'], root_disk_hash['type'])
      @ephemeral_disk = Bosh::AzureCloud::EphemeralDisk.new(
        ephemeral_disk_hash['use_root_disk'].nil? ? false : ephemeral_disk_hash['use_root_disk'],
        ephemeral_disk_hash['size'],
        ephemeral_disk_hash['type']
      )

      @location = global_azure_config.location
    end

    private

    # In AzureStack, availability sets can only be configured with 1 update domain.
    # In Azure, the max update domain count of a managed/unmanaged availability set is 5.
    def _default_update_domain_count(global_azure_config)
      global_azure_config.environment == ENVIRONMENT_AZURESTACK ? 1 : 5
    end

    # In AzureStack, availability sets can only be configured with 1 fault domain and 1 update domain.
    # In Azure, the max fault domain count of an unmanaged availability set is 3;
    #           the max fault domain count of a managed availability set is 2 in some regions.
    #           When all regions support 3 fault domains, the default value should be changed to 3.
    def _default_fault_domain_count(global_azure_config)
      if global_azure_config.environment == ENVIRONMENT_AZURESTACK
        1
      else
        global_azure_config.use_managed_disks ? 2 : 3
      end
    end

    def _parse_load_balancer_config(vm_properties, global_azure_config)
      if vm_properties[LOAD_BALANCER_KEY].is_a?(Hash)
        resource_group_name = vm_properties[LOAD_BALANCER_KEY][RESOURCE_GROUP_NAME_KEY] || global_azure_config.resource_group_name
        Bosh::AzureCloud::LoadBalancerConfig.new(
          resource_group_name,
          vm_properties[LOAD_BALANCER_KEY][NAME_KEY]
        )
      else
        Bosh::AzureCloud::LoadBalancerConfig.new(
          global_azure_config.resource_group_name,
          vm_properties[LOAD_BALANCER_KEY]
        )
      end
    end

    def _parse_availability_set_config(vm_properties, global_azure_config)
      if vm_properties[AVAILABILITY_SET_KEY].is_a?(Hash)
        platform_update_domain_count = vm_properties[AVAILABILITY_SET_KEY]['platform_update_domain_count'] || _default_update_domain_count(global_azure_config)
        platform_fault_domain_count = vm_properties[AVAILABILITY_SET_KEY]['platform_fault_domain_count'] || _default_fault_domain_count(global_azure_config)
        Bosh::AzureCloud::AvailabilitySetConfig.new(
          vm_properties[AVAILABILITY_SET_KEY][NAME_KEY],
          platform_update_domain_count,
          platform_fault_domain_count
        )
      else
        platform_update_domain_count = vm_properties['platform_update_domain_count'] || _default_update_domain_count(global_azure_config)
        platform_fault_domain_count = vm_properties['platform_fault_domain_count'] || _default_fault_domain_count(global_azure_config)
        Bosh::AzureCloud::AvailabilitySetConfig.new(
          vm_properties[AVAILABILITY_SET_KEY],
          platform_update_domain_count,
          platform_fault_domain_count
        )
      end
    end
  end
end
