# frozen_string_literal: true

module Bosh::AzureCloud
  class InstanceIdFactory
    def self.build(bosh_vm_meta, vm_props, use_managed_disks)
      if use_managed_disks
        instance_id = InstanceId.create(vm_props.resource_group_name, bosh_vm_meta.agent_id)
      else
        storage_account = get_storage_account_from_vm_properties(vm_props, vm_props.location) # TODO:change
        instance_id = InstanceId.create(vm_props.resource_group_name, bosh_vm_meta.agent_id, storage_account[:name])
      end
      instance_id
    end

    def self.validate(config_hash)
    end
  end
end
