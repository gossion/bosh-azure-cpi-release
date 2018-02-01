#module Bosh::AzureCloud
  class WireClient
    def initialize()
      @distro = "ubuntu"
      #ubuntu
      leases_path = '/var/lib/dhcp/dhclient.*.leases'
      #centos
      leases_path = '/var/lib/dhclient/dhclient-*.leases'
      @endpoint = detect_wire_server(leases_path)
    end

    #
    #  Try to discover and decode the wireserver endpoint in the
    #  specified dhcp leases path.
    #  :param pathglob: The path containing dhcp lease files
    #  :return: The endpoint if available, otherwise nil
    #
    def get_endpoint_from_leases_path(leases_path)
      #https://github.com/Azure/WALinuxAgent/blob/8c38bd6c7aa367e9d077ef454a0f96cdb1dd7bb7/azurelinuxagent/common/osutil/default.py#L806
      @endpoint = "168.63.129.16"
    end

    def send_events(event_list)
      #https://github.com/Azure/WALinuxAgent/blob/f52a9a546d9005ad15ec1af47aeaa46169374dbf/azurelinuxagent/common/protocol/wire.py#L1004
    end
  end
#end
