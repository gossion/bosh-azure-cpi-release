require "spec_helper"

describe Bosh::AzureCloud::NetworkConfigurator do

  let(:dynamic) {
    {
      "type" => "dynamic",
      "cloud_properties" =>
        {
          "subnet_name" => "bar",
          "virtual_network_name" => "foo"
        }
    }
  }
  let(:manual) {
    {
      "type" => "manual",
      "ip"=>"fake-ip",
      "cloud_properties" =>
        {
          "resource_group_name" => "fake-rg",
          "subnet_name" => "bar",
          "virtual_network_name" => "foo",
          "security_group" => "fake-nsg"
        }
    }
  }
  let(:vip) {
    {
      "type" => "vip"
    }
  }

  it "should raise an error if the spec isn't a hash" do
    expect {
      Bosh::AzureCloud::NetworkConfigurator.new("foo")
    }.to raise_error ArgumentError
  end

  describe "network types" do
    it "should create a ManualNetwork when network type is manual" do
      network_spec = {
        "network1" => manual
      }
      nc = Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      expect(nc.networks.length).to eq(1)
      expect(nc.networks[0]).to be_a Bosh::AzureCloud::ManualNetwork
    end

    it "should create a DynamicNetwork when network type is dynamic" do
      network_spec = {
        "network1" => dynamic
      }
      nc = Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      expect(nc.networks.length).to eq(1)
      expect(nc.networks[0]).to be_a Bosh::AzureCloud::DynamicNetwork
    end

    it "should create a VipNetwork instance when network has vip configured" do
      network_spec = {
        "network1" => manual,
        "network2" => vip,
        "network3" => dynamic
      }
      nc = Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      expect(nc.vip_network).to be_a Bosh::AzureCloud::VipNetwork
      expect(nc.networks.length).to eq(2)
    end

    it "should not raise an error if one dynamic network is defined" do
      network_spec = {
        "network1" => dynamic
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      }.not_to raise_error
    end

    it "should not raise an error if one manual network is defined" do
      network_spec = {
        "network1" => manual
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      }.not_to raise_error
    end

    it "should not raise an error if both dynamic and manual networks are defined" do
      network_spec = {
        "network1" => dynamic,
        "network2" => manual
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      }.not_to raise_error
    end

    it "should raise an error if neither dynamic nor manual network is defined" do
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new("network1" => vip)
      }.to raise_error Bosh::Clouds::CloudError, "At least one dynamic or manual network must be defined"
    end

    it "should raise an error if multiple vip networks are defined" do
      network_spec = {
        "network1" => vip,
        "network2" => vip
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "More than one vip network for `network2'"
    end

    it "should not raise an error if multiple dynamic networks are defined" do
      network_spec = {
        "network1" => dynamic,
        "network2" => dynamic
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      }.not_to raise_error
    end

    it "should not raise an error if multiple manual networks are defined" do
      network_spec = {
        "network1" => manual,
        "network2" => manual
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      }.not_to raise_error
    end

    it "should raise an error if an illegal network type is used" do
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new("network1" => {"type" => "foo"})
      }.to raise_error Bosh::Clouds::CloudError, "Invalid network type `foo' for Azure, " \
                        "can only handle `dynamic', `vip', or `manual' network types"
    end
  end

  describe  "uncomplete network spec" do
    it "should raise an error if subnet_name is missed in one dynamic network" do
      dynamic["cloud_properties"].delete("subnet_name")
      network_spec = {
          "network1" => dynamic
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "subnet_name required for dynamic network"
    end

    it "should raise an error if virtual_network_name is missed in one dynamic network" do
      dynamic["cloud_properties"].delete("virtual_network_name")
      network_spec = {
        "network1" => dynamic
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "virtual_network_name required for dynamic network"
    end

    it "should raise an error if subnet_name is missed in one manual network" do
      manual["cloud_properties"].delete("subnet_name")
      network_spec = {
        "network1" => manual
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "subnet_name required for manual network"
    end

    it "should raise an error if virtual_network_name is missed in one manual network" do
      manual["cloud_properties"].delete("virtual_network_name")
      network_spec = {
        "network1" => manual
      }
      expect {
        Bosh::AzureCloud::NetworkConfigurator.new(network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "virtual_network_name required for manual network"
    end
  end
end
