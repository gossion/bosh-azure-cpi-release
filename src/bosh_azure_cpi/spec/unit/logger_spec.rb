require 'spec_helper'

describe Bosh::AzureCloud::RetryableLogger do
  let(:logger_instance) { double("logger") }
  let(:logger) { Bosh::AzureCloud::RetryableLogger.new(logger_instance) }

  let(:message) { "fake-message" }

  describe "#debug" do
    context "when no error happens" do
      it "should log the message" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:debug).with(message)
        expect{
          logger.debug(message)
        }.not_to raise_error
      end
    end

    context "when error happens" do
      before do
        allow(logger_instance).to receive(:debug).with(message).
          and_raise('error')
      end

      it "should try to log the message and swallow the exception" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:debug).exactly(3).times
        expect(logger).to receive(:sleep).twice
        expect{
          logger.debug(message)
        }.not_to raise_error
      end
    end
  end

  describe "#info" do
    context "when no error happens" do
      it "should log the message" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:info).with(message)
        expect{
          logger.info(message)
        }.not_to raise_error
      end
    end

    context "when error happens" do
      before do
        allow(logger_instance).to receive(:info).with(message).
          and_raise('error')
      end

      it "should try to log the message and swallow the exception" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:info).exactly(3).times
        expect(logger).to receive(:sleep).twice
        expect{
          logger.info(message)
        }.not_to raise_error
      end
    end
  end

  describe "#warn" do
    context "when no error happens" do
      it "should log the message" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:warn).with(message)
        expect{
          logger.warn(message)
        }.not_to raise_error
      end
    end

    context "when error happens" do
      before do
        allow(logger_instance).to receive(:warn).with(message).
          and_raise('error')
      end

      it "should try to log the message and swallow the exception" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:warn).exactly(3).times
        expect(logger).to receive(:sleep).twice
        expect{
          logger.warn(message)
        }.not_to raise_error
      end
    end
  end

  describe "#error" do
    context "when no error happens" do
      it "should log the message" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:error).with(message)
        expect{
          logger.error(message)
        }.not_to raise_error
      end
    end

    context "when error happens" do
      before do
        allow(logger_instance).to receive(:error).with(message).
          and_raise('error')
      end

      it "should try to log the message and swallow the exception" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:error).exactly(3).times
        expect(logger).to receive(:sleep).twice
        expect{
          logger.error(message)
        }.not_to raise_error
      end
    end
  end

  describe "#fatal" do
    context "when no error happens" do
      it "should log the message" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:fatal).with(message)
        expect{
          logger.fatal(message)
        }.not_to raise_error
      end
    end

    context "when error happens" do
      before do
        allow(logger_instance).to receive(:fatal).with(message).
          and_raise('fatal')
      end

      it "should try to log the message and swallow the exception" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:fatal).exactly(3).times
        expect(logger).to receive(:sleep).twice
        expect{
          logger.fatal(message)
        }.not_to raise_error
      end
    end
  end

  describe "#unknown" do
    context "when no error happens" do
      it "should log the message" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:unknown).with(message)
        expect{
          logger.unknown(message)
        }.not_to raise_error
      end
    end

    context "when error happens" do
      before do
        allow(logger_instance).to receive(:unknown).with(message).
          and_raise('unknown')
      end

      it "should try to log the message and swallow the exception" do
        expect(logger).to receive(:retryable).and_call_original
        expect(logger_instance).to receive(:unknown).exactly(3).times
        expect(logger).to receive(:sleep).twice
        expect{
          logger.unknown(message)
        }.not_to raise_error
      end
    end
  end

  describe "#set_request_id" do
    let(:id) { "fake-id" }

    it "should set request id" do
      expect(logger_instance).to receive(:set_request_id).with(id)
      expect{
        logger.set_request_id(id)
      }.not_to raise_error
    end
  end

  describe "retryable" do
    context "when the block is executed successfully" do
      let(:result) { 'fake-result' }

      it "should return the result" do
        expect(
          logger.send(:retryable) do
            result
          end
        ).to eq(result)
      end
    end

    context "when error happens" do
      let(:fake_instance) { double("fake-instance") }

      before do
        allow(fake_instance).to receive(:func).and_raise "fake-error"
      end

      context "when ignore_exception is true" do
        let(:retries) { 2 }
        let(:sleep) { 2 }
        let(:ignore_exception) { true }
        let(:options) {
          {
            :retries => retries,
            :sleep => sleep,
            :ignore_exception => ignore_exception
          }
        }

        it "should retry and not raise error" do
          expect(logger).to receive(:sleep).with(sleep).exactly(retries).times
          expect(fake_instance).to receive(:func).exactly(retries + 1).times
          expect{
            logger.send(:retryable, options) do
              fake_instance.func()
            end
          }.not_to raise_error
        end
      end

      context "when ignore_exception is false" do
        let(:retries) { 2 }
        let(:sleep) { 2 }
        let(:ignore_exception) { false }
        let(:options) {
          {
            :retries => retries,
            :sleep => sleep,
            :ignore_exception => ignore_exception
          }
        }

        it "should retry and raise error" do
          expect(logger).to receive(:sleep).with(sleep).exactly(retries).times
          expect(fake_instance).to receive(:func).exactly(retries + 1).times
          expect{
            logger.send(:retryable, options) do
              fake_instance.func()
            end
          }.to raise_error /fake-error/
        end
      end

      context "when the block passes with retry" do
        let(:result) { "fake-result" }
        let(:retries) { 2 }
        let(:sleep) { 2 }
        let(:ignore_exception) { false }
        let(:options) {
          {
            :retries => retries,
            :sleep => sleep,
            :ignore_exception => ignore_exception
          }
        }

        before do
          @times_called = 0
          allow(fake_instance).to receive(:func) do
            @times_called += 1
            raise "fake-error" if @times_called == 1 #raise error 1 time
            result
          end
        end

        it "should retry and return correct value" do
          expect(logger).to receive(:sleep).with(sleep).exactly(1).times
          expect(fake_instance).to receive(:func).exactly(2).times
          expect(
            logger.send(:retryable, options) do
              fake_instance.func()
            end
          ).to eq(result)
        end
      end
    end
  end
end
