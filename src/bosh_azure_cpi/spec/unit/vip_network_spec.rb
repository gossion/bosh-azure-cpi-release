require "spec_helper"

describe Bosh::AzureCloud::VipNetwork do
  describe "everything is fine" do
    let(:network_spec) {
      {
        "type" => "vip",
        "ip"=>"fake-vip",
        "cloud_properties" => {}
      }
    }

    let(:with_resource_group_specth) {
      {
        "type" => "vip",
        "ip"=>"fake-vip",
        "cloud_properties" => {
          "resource_group_name" => "foo"
        }
      }
    }

    it "should get ip with right value" do
      nc = Bosh::AzureCloud::VipNetwork.new("vip", network_spec)
      expect(nc.public_ip).to eq("fake-vip")
    end

    it "should get nil when not having resource_group_name in cloud_properties" do
      nc = Bosh::AzureCloud::VipNetwork.new("vip", network_spec)
      expect(nc.resource_group_name).to eq(nil)
    end

    it "should get right resource_group_name when having resource_group_name in cloud_properties" do
      nc = Bosh::AzureCloud::VipNetwork.new("vip", with_resource_group_specth)
      expect(nc.resource_group_name).to eq("foo")
    end
  end
end
