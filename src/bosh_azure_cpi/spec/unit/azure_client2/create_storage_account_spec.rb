require 'spec_helper'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

describe Bosh::AzureCloud::AzureClient2 do
  let(:logger) { Bosh::AzureCloud::RetryableLogger.new(Bosh::Clouds::Config.logger) }
  let(:azure_client2) {
    Bosh::AzureCloud::AzureClient2.new(
      mock_cloud_options["properties"]["azure"],
      logger
    )
  }
  let(:subscription_id) { mock_azure_properties['subscription_id'] }
  let(:tenant_id) { mock_azure_properties['tenant_id'] }
  let(:token_api_version) { AZURE_API_VERSION }
  let(:token_uri) { "https://login.microsoftonline.com/#{tenant_id}/oauth2/token?api-version=#{token_api_version}" }
  let(:valid_access_token) { "valid-access-token" }
  let(:expires_on) { (Time.now+1800).to_i.to_s }

  let(:storage_api_version) { AZURE_RESOURCE_PROVIDER_STORAGE }
  let(:storage_account_name) { 'fake-storage-account-name' }
  let(:location) { "fake-location" }
  let(:account_type) { "Standard_LRS" }
  let(:tags) { { "foo" => "bar" } }

  let(:request_id) { "fake-request-id" }
  let(:operation_status_link) { "https://management.azure.com/subscriptions/#{subscription_id}/operations/#{request_id}" }

  describe "#create_storage_account" do
    let(:storage_account_uri) { "https://management.azure.com//subscriptions/#{subscription_id}/resourceGroups/#{MOCK_RESOURCE_GROUP_NAME}/providers/Microsoft.Storage/storageAccounts/#{storage_account_name}?api-version=#{storage_api_version}" }
    let(:request_body) {
      {
        :location   => location,
        :tags       => tags,
        :properties => {
          :accountType => account_type
        }
      }
    }

    context "when the response status code is 200" do
      it "should create the storage account without errors" do
        stub_request(:post, token_uri).to_return(
          :status => 200,
          :body => {
            "access_token" => valid_access_token,
            "expires_on" => expires_on
          }.to_json,
          :headers => {})
        stub_request(:put, storage_account_uri).with(body: request_body).to_return(
          :status => 200,
          :body => '',
          :headers => {})

        expect(
          azure_client2.create_storage_account(storage_account_name, location, account_type, tags)
        ).to be(true)
      end
    end

    context "when the response status code is neither 200 nor 202" do
      it "should raise an error" do
        stub_request(:post, token_uri).to_return(
          :status => 200,
          :body => {
            "access_token" => valid_access_token,
            "expires_on" => expires_on
          }.to_json,
          :headers => {})
        stub_request(:put, storage_account_uri).with(body: request_body).to_return(
          :status => 404,
          :body => '',
          :headers => {})

        expect {
          azure_client2.create_storage_account(storage_account_name, location, account_type, tags)
        }.to raise_error(/create_storage_account - Cannot create the storage account `#{storage_account_name}'. http code: 404/)
      end
    end

    context "when the response status code is 202" do
      let(:default_retry_after) { 10 }

      context "when the status code of the response to the asynchronous operation is 200" do
        context "when the provisioning state is Succeeded" do
          it "should create the storage account without errors" do
            stub_request(:post, token_uri).to_return(
              :status => 200,
              :body => {
                "access_token" => valid_access_token,
                "expires_on" => expires_on
              }.to_json,
              :headers => {})
            stub_request(:put, storage_account_uri).with(body: request_body).to_return(
              :status => 202,
              :body => '',
              :headers => {
                "Location" => operation_status_link
              })
            stub_request(:get, operation_status_link).to_return(
              :status => 200,
              :body => '{"status":"Succeeded"}',
              :headers => {})

            expect(azure_client2).to receive(:sleep).with(default_retry_after)
            expect(
              azure_client2.create_storage_account(storage_account_name, location, account_type, tags)
            ).to be(true)
          end
        end

        context "when the provisioning state is Failed" do
          context "when there is no Retry-After in the response header" do
            it "should raise an error" do
              stub_request(:post, token_uri).to_return(
                :status => 200,
                :body => {
                  "access_token" => valid_access_token,
                  "expires_on" => expires_on
                }.to_json,
                :headers => {})
              stub_request(:put, storage_account_uri).with(body: request_body).to_return(
                :status => 202,
                :body => '',
                :headers => {
                  "Location" => operation_status_link
                })
              stub_request(:get, operation_status_link).to_return(
                :status => 200,
                :body => '{"status":"Failed"}',
                :headers => {})

              expect(azure_client2).to receive(:sleep).with(default_retry_after)
              expect {
                azure_client2.create_storage_account(storage_account_name, location, account_type, tags)
              }.to raise_error(/Error message: {"status":"Failed"}/)
            end
          end

          context "when there is Retry-After in the response header" do
            it "should create the storage account after retry" do
              stub_request(:post, token_uri).to_return(
                :status => 200,
                :body => {
                  "access_token" => valid_access_token,
                  "expires_on" => expires_on
                }.to_json,
                :headers => {})
              stub_request(:put, storage_account_uri).with(body: request_body).to_return(
                :status => 202,
                :body => '',
                :headers => {
                  "Location" => operation_status_link
                })
              stub_request(:get, operation_status_link).to_return(
                {
                  :status => 200,
                  :body => '{"status":"Failed"}',
                  :headers => {
                    'Retry-After' => '1'
                  }
                },
                {
                  :status => 200,
                  :body => '{"status":"Succeeded"}',
                  :headers => {}
                }
              )

              expect(azure_client2).to receive(:sleep).with(default_retry_after)
              expect(azure_client2).to receive(:sleep).with(1)
              expect(
                azure_client2.create_storage_account(storage_account_name, location, account_type, tags)
              ).to be(true)
            end
          end
        end
      end

      context "when the status code of the response to the asynchronous operation is not one of 200 and 202" do
        it "should raise an error" do
          stub_request(:post, token_uri).to_return(
            :status => 200,
            :body => {
              "access_token" => valid_access_token,
              "expires_on" => expires_on
            }.to_json,
            :headers => {})
          stub_request(:put, storage_account_uri).with(body: request_body).to_return(
            :status => 202,
            :body => '',
            :headers => {
              "Location" => operation_status_link
            })
          stub_request(:get, operation_status_link).to_return(
            {
              :status => 404,
              :body => 'fake-response-body',
              :headers => {}
            }
          )

          expect(azure_client2).to receive(:sleep).with(default_retry_after)
          expect {
            azure_client2.create_storage_account(storage_account_name, location, account_type, tags)
          }.to raise_error(/create_storage_account - http code: 404. Error message: fake-response-body/)
        end
      end
    end
  end
end
