require 'spec_helper'

describe Bosh::AzureCloud::TelemetryManager do
  describe '#monitor' do
    #TODO: Add case
  end

  describe '#run' do
    let(:logger) { instance_double(Logger) }
    let(:telemetry_manager) { Bosh::AzureCloud::TelemetryManager.new(mock_azure_properties, logger) }
    let(:telemetry_event) { instance_double(Bosh::AzureCloud::TelemetryEvent) }

    let(:operation) { 'fake-op' }
    let(:extras) { {'fake-key' => 'fake-value'} }

    let(:event_param_name) { instance_double(Bosh::AzureCloud::TelemetryEventParam) }
    let(:event_param_version) { instance_double(Bosh::AzureCloud::TelemetryEventParam) }
    let(:event_param_operation) { instance_double(Bosh::AzureCloud::TelemetryEventParam) }
    let(:event_param_operation_success) { instance_double(Bosh::AzureCloud::TelemetryEventParam) }
    let(:event_param_message) { instance_double(Bosh::AzureCloud::TelemetryEventParam) }
    let(:event_param_duration) { instance_double(Bosh::AzureCloud::TelemetryEventParam) }

    before do
      allow(Bosh::AzureCloud::TelemetryEventParam).to receive(:new).
        with("Name", "BOSH-CPI").
        and_return(event_param_name)
      allow(Bosh::AzureCloud::TelemetryEventParam).to receive(:new).
        with("Version", Bosh::AzureCloud::VERSION).
        and_return(event_param_version)
      allow(Bosh::AzureCloud::TelemetryEventParam).to receive(:new).
        with("Operation", operation).
        and_return(event_param_operation)
      allow(Bosh::AzureCloud::TelemetryEventParam).to receive(:new).
        with("OperationSuccess", true).
        and_return(event_param_operation_success)
      allow(Bosh::AzureCloud::TelemetryEventParam).to receive(:new).
        with("Message", "").
        and_return(event_param_message)
      allow(Bosh::AzureCloud::TelemetryEventParam).to receive(:new).
        with("Duration", 0).
        and_return(event_param_duration)

      allow(event_param_duration).to receive(:value=)
      allow(event_param_message).to receive(:value=)

      allow(Bosh::AzureCloud::TelemetryEvent).to receive(:new).
        and_return(telemetry_event)
      allow(telemetry_event).to receive(:add_param).with(event_param_name)
      allow(telemetry_event).to receive(:add_param).with(event_param_version)
      allow(telemetry_event).to receive(:add_param).with(event_param_operation)
      allow(telemetry_event).to receive(:add_param).with(event_param_operation_success)
      allow(telemetry_event).to receive(:add_param).with(event_param_message)
      allow(telemetry_event).to receive(:add_param).with(event_param_duration)

      allow(telemetry_manager).to receive(:report_event)
    end

    context 'when the block is executed successfully' do
      let(:result) { 'fake-result' }

      it 'should return the result' do
        expect(event_param_message).to receive(:value=).
          with({'msg' => 'Successed',
                'subscription_id' => mock_azure_properties['subscription_id'],
                'fake-key' => 'fake-value'})

        expect(
          telemetry_manager.send(:run, operation, extras) do
            result
          end
        ).to eq(result)
      end
    end

    context 'when the block raises an error' do
      context 'when length of the message exceeds 3.9 kB' do
        let(:error) { 'x'*3994 }
        let(:runtime_error_prefix) { '#<RuntimeError: ' }
        let(:error_message) { "#{runtime_error_prefix}#{error}"[0...3990] + '...' }

        it 'should truncate the message and raise the error' do
          expect(event_param_operation_success).to receive(:value=).
            with(false)
          expect(event_param_message).to receive(:value=).
            with(hash_including('msg' => error_message))

          expect{
            telemetry_manager.send(:run, operation, extras) do
              raise error
            end
          }.to raise_error error
        end
      end

      context 'when length of the message does not exceed 3.9 kB' do
        let(:error) { 'x' }
        let(:runtime_error_prefix) { '#<RuntimeError: ' }
        let(:error_message) { "#{runtime_error_prefix}#{error}" }

        it 'should raise the error' do
          expect(event_param_operation_success).to receive(:value=).
            with(false)
          expect(event_param_message).to receive(:value=).
            with(hash_including('msg' => /#{error_message}/))

          expect{
            telemetry_manager.send(:run, operation, extras) do
              raise error
            end
          }.to raise_error error
        end
      end
    end
  end

  describe '#report_event' do
    let(:logger) { instance_double(Logger) }
    let(:telemetry_manager) { Bosh::AzureCloud::TelemetryManager.new(mock_azure_properties, logger) }
    let(:telemetry_event) { instance_double(Bosh::AzureCloud::TelemetryEvent) }
    let(:telemetry_event_handler) { instance_double(Bosh::AzureCloud::TelemetryEventHandler) }
    let(:file) { double('file')}

    context 'when everything is ok' do
      before do
        allow(File).to receive(:open).and_return(file)
        allow(file).to receive(:write)
        allow(Open3).to receive(:capture3).and_return(['fake-stdout', 'fake-stderr', 0])
        allow(telemetry_event).to receive(:to_json).and_return('fake-event')
      end

      it 'should collect and sent events' do
        expect(telemetry_manager).to receive(:fork)
        expect(Process).to receive(:detach)
        expect {
          telemetry_manager.send(:report_event, telemetry_event)
        }.not_to raise_error
      end
    end

    context 'when it fails to move event file to CPI_EVENTS_DIR' do
      let(:err_status) { 1 }

      before do
        allow(File).to receive(:open).and_return(file)
        allow(file).to receive(:write)
        allow(Open3).to receive(:capture3).and_return(['fake-stdout', 'fake-stderr', err_status])
        allow(telemetry_event).to receive(:to_json).and_return('fake-event')
      end

      it 'should log the error and drop it silently' do
        expect(logger).to receive(:warn).with(/fake-stderr/)
        expect(Bosh::AzureCloud::TelemetryEventHandler).not_to receive(:new)

        expect {
          telemetry_manager.send(:report_event, telemetry_event)
        }.not_to raise_error
      end
    end

    context 'when exception is caught' do
      before do
        allow(File).to receive(:open).and_raise 'failed to open file'
      end

      it 'should log the error and drop the exception silently' do
        expect(logger).to receive(:warn).with(/failed to open file/)
        expect(Bosh::AzureCloud::TelemetryEventHandler).not_to receive(:new)

        expect {
          telemetry_manager.send(:report_event, telemetry_event)
        }.not_to raise_error
      end
    end
  end
end
