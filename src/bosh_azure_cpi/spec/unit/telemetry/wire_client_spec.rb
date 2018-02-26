require 'spec_helper'

describe Bosh::AzureCloud::WireClient do
  describe "post_data" do
    let(:logger) { instance_double(Logger) }
    let(:wire_client) { Bosh::AzureCloud::WireClient.new(logger) }
    let(:endpoint) { "fake-endpoint" }

    before do
      allow(wire_client).to receive(:get_endpoint).and_return(endpoint)
    end

    #TODO
  end

  describe "get_endpoint" do
    let(:logger) { instance_double(Logger) }
    let(:wire_client) { Bosh::AzureCloud::WireClient.new(logger) }
    let(:endpoint) { "fake-endpoint" }

    context "when OS is Ubuntu" do
      #TODO: replace this with file content got from stemcell VM.
      let(:lsb_release) { '
DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=16.04
DISTRIB_CODENAME=xenial
DISTRIB_DESCRIPTION="Ubuntu 16.04.3 LTS"
      ' }

      before do
        allow(File).to receive(:exists?).with("/etc/lsb-release").and_return(true)
        allow(File).to receive(:exists?).with("/etc/centos-release").and_return(false)
        allow(File).to receive(:read).with("/etc/lsb-release").and_return(lsb_release)
      end

      it "should get endpoint for Ubuntu" do
        expect(wire_client).to receive(:get_endpoint_from_leases_path).
          with("/var/lib/dhcp/dhclient.*.leases").
          and_return(endpoint)
        expect(
          wire_client.send(:get_endpoint)
        ).to eq(endpoint)
      end
    end

    context "when OS is CentOS" do
      #TODO: replace this with file content got from stemcell VM.
      let(:centos_release) { '
CentOS Linux release 7.4.1708 (Core)
      ' }

      before do
        allow(File).to receive(:exists?).with("/etc/lsb-release").and_return(false)
        allow(File).to receive(:exists?).with("/etc/centos-release").and_return(true)
        allow(File).to receive(:read).with("/etc/centos-release").and_return(centos_release)
      end

      it "should get endpoint for CentOS" do
        expect(wire_client).to receive(:get_endpoint_from_leases_path).
          with("/var/lib/dhclient/dhclient-*.leases").
          and_return(endpoint)
        expect(
          wire_client.send(:get_endpoint)
        ).to eq(endpoint)
      end
    end
  end

  describe "get_endpoint_from_leases_path" do
    let(:logger) { instance_double(Logger) }
    let(:wire_client) { Bosh::AzureCloud::WireClient.new(logger) }

    let(:lease_path) { "fake-path" }
    let(:lease_file) { "/tmp/cpi-test-fake-lease-file-name" }
    let(:lease_content) { '
lease {
  interface "eth0";
  fixed-address 172.16.3.4;
  server-name "SG20103202064";
  option subnet-mask 255.255.255.0;
  option dhcp-lease-time 4294967295;
  option routers 172.16.3.1;
  option dhcp-message-type 5;
  option dhcp-server-identifier 168.63.129.16;
  option domain-name-servers 168.63.129.16;
  option dhcp-renewal-time 4294967295;
  option rfc3442-classless-static-routes 0,172,16,3,1,32,168,63,129,16,172,16,3,1,32,169,254,169,254,172,16,3,1;
  option unknown-245 a8:3f:81:10;
  option dhcp-rebinding-time 4294967295;
  option domain-name "ta1qcq3khvnelp4p0x3q10hsjh.ix.internal.cloudapp.net";
  renew 6 2017/11/25 01:48:29;
  rebind 6 2017/11/25 01:48:29;
  expire 6 2017/11/25 01:48:29;
}
lease {
  interface "eth0";
  fixed-address 172.16.3.4;
  server-name "SG20103202064";
  option subnet-mask 255.255.255.0;
  option dhcp-lease-time 4294967295;
  option routers 172.16.3.1;
  option dhcp-message-type 5;
  option dhcp-server-identifier 168.63.129.16;
  option domain-name-servers 168.63.129.16;
  option dhcp-renewal-time 4294967295;
  option rfc3442-classless-static-routes 0,172,16,3,1,32,168,63,129,16,172,16,3,1,32,169,254,169,254,172,16,3,1;
  option unknown-245 a8:3f:81:10;
  option dhcp-rebinding-time 4294967295;
  option domain-name "ta1qcq3khvnelp4p0x3q10hsjh.ix.internal.cloudapp.net";
  renew 2 2154/01/01 08:18:55;
  rebind 2 2154/01/01 08:18:55;
  expire 2 2154/01/01 08:18:55;
}
    ' }

    before do
      allow(Dir).to receive(:glob).and_return([lease_file])
      File.open(lease_file, 'w') do |file|
        file.write(lease_content)
      end
    end

    after do
      File.delete(lease_file)
    end

    it "should get the endpoint correctly" do
      expect(wire_client).to receive(:get_ip_from_lease_value).
        with("a8:3f:81:10").
        and_call_original.twice
      expect(
        wire_client.send(:get_endpoint_from_leases_path, lease_path)
      ).to eq("168.63.129.16") #Note: a8:3f:81:10 is translated to 168.63.129.16
    end

    #TODO: more cases
    # 1. return nil
    # 2. all expired
  end

  describe "get_ip_from_lease_value" do
    let(:logger) { instance_double(Logger) }
    let(:wire_client) { Bosh::AzureCloud::WireClient.new(logger) }
    let(:lease_value) { "a8:3f:81:10" }
    let(:ip) { "168.63.129.16" }

    it "should decode the ip correctly" do
      expect(
        wire_client.send(:get_ip_from_lease_value, lease_value)
      ).to eq(ip)
    end
  end
end
