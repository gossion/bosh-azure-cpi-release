require 'spec_helper'

describe Bosh::AzureCloud::TelemetryEvent do
  describe "#parse_hash" do
    let(:hash) {
      {
        "eventId" => "fake-event-id",
        "providerId" => "fake-provider-id",
        "parameters" => [
          {
            "name" => "fake-name1",
            "value" => "fake-value1"
          },
          {
            "name" => "fake-name2",
            "value" => "fake-value2"
          }
        ]
      }
    }
    let(:parameter) { instance_double(Bosh::AzureCloud::TelemetryEventParam) }

    before do
      allow(Bosh::AzureCloud::TelemetryEventParam).to receive(:parse_hash).
        and_return(parameter)
    end

    it "should parse the hash and create an instance" do
      expect(Bosh::AzureCloud::TelemetryEvent).to receive(:new).
        with(hash["eventId"], hash["providerId"], parameters: [parameter, parameter])

      expect{
        Bosh::AzureCloud::TelemetryEvent.parse_hash(hash)
      }.not_to raise_error
    end
  end

  describe "#add_param" do
    context "when parameter is a TelemetryEventParam" do
      let(:event) {  Bosh::AzureCloud::TelemetryEvent.new("fake-event-id", "fake-provider-id") }
      let(:parameter) { Bosh::AzureCloud::TelemetryEventParam.new("fake-name1", "fake-value1") }

      it "should add the parameter" do
        expect(event.parameters).to receive(:push).with(parameter)
        expect{
          event.add_param(parameter)
        }.not_to raise_error
      end
    end

    context "when parameter is not a TelemetryEventParam" do
      let(:event) {  Bosh::AzureCloud::TelemetryEvent.new("fake-event-id", "fake-provider-id") }
      let(:parameter) { double("pamameter") }

      it "should add the parameter" do
        expect(event.parameters).not_to receive(:push).with(parameter)
        expect{
          event.add_param(parameter)
        }.not_to raise_error
      end
    end
  end

  describe "#to_hash" do
    let(:hash) {
      {
        "eventId" => "fake-event-id",
        "providerId" => "fake-provider-id",
        "parameters" => [
          {
            "name" => "fake-name1",
            "value" => "fake-value1"
          },
          {
            "name" => "fake-name2",
            "value" => "fake-value2"
          }
        ]
      }
    }

    let(:parameter1) { Bosh::AzureCloud::TelemetryEventParam.new("fake-name1", "fake-value1") }
    let(:parameter2) { Bosh::AzureCloud::TelemetryEventParam.new("fake-name2", "fake-value2") }
    let(:event) { Bosh::AzureCloud::TelemetryEvent.new("fake-event-id", "fake-provider-id", parameters: [parameter1, parameter2]) }

    it "should return with right value" do
      expect(event.to_hash).to eq(hash)
    end
  end

  describe "#to_json" do
    let(:json) {
      {
        "eventId" => "fake-event-id",
        "providerId" => "fake-provider-id",
        "parameters" => [
          {
            "name" => "fake-name1",
            "value" => "fake-value1"
          },
          {
            "name" => "fake-name2",
            "value" => "fake-value2"
          }
        ]
      }.to_json
    }

    let(:parameter1) { Bosh::AzureCloud::TelemetryEventParam.new("fake-name1", "fake-value1") }
    let(:parameter2) { Bosh::AzureCloud::TelemetryEventParam.new("fake-name2", "fake-value2") }
    let(:event) { Bosh::AzureCloud::TelemetryEvent.new("fake-event-id", "fake-provider-id", parameters: [parameter1, parameter2]) }

    it "should return with right value" do
      expect(event.to_json).to eq(json)
    end
  end

  describe "#to_xml" do
    let(:parameter1) { Bosh::AzureCloud::TelemetryEventParam.new("fake-name1", "fake-value1") }
    let(:parameter2) { Bosh::AzureCloud::TelemetryEventParam.new("fake-name2", "fake-value2") }
    let(:event) { Bosh::AzureCloud::TelemetryEvent.new("fake-event-id", "fake-provider-id", parameters: [parameter1, parameter2]) }

    it "should return with right value" do
      expect(event.to_xml).to eq("<Provider id=\"fake-provider-id\"><Event id=\"fake-event-id\"><![CDATA[<Param Name=\"fake-name1\" Value=\"fake-value1\" T=\"mt:wstr\" /><Param Name=\"fake-name2\" Value=\"fake-value2\" T=\"mt:wstr\" />]]></Event></Provider>")
    end
  end

  describe "#to_xml_without_provider" do
    let(:parameter1) { Bosh::AzureCloud::TelemetryEventParam.new("fake-name1", "fake-value1") }
    let(:parameter2) { Bosh::AzureCloud::TelemetryEventParam.new("fake-name2", "fake-value2") }
    let(:event) { Bosh::AzureCloud::TelemetryEvent.new("fake-event-id", "fake-provider-id", parameters: [parameter1, parameter2]) }

    it "should return with right value" do
      expect(event.to_xml_without_provider).to eq("<Event id=\"fake-event-id\"><![CDATA[<Param Name=\"fake-name1\" Value=\"fake-value1\" T=\"mt:wstr\" /><Param Name=\"fake-name2\" Value=\"fake-value2\" T=\"mt:wstr\" />]]></Event>")
    end
  end
end

