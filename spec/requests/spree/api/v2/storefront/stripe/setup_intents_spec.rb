require 'spec_helper'

RSpec.describe Spree::Api::V2::Storefront::Stripe::SetupIntentsController, type: :request do
  let(:store) { Spree::Store.default }
  let!(:gateway) { create(:stripe_gateway, stores: [store]) }
  let!(:user) { create(:user) }
  let(:service_response) do
    Spree::ServiceModule::Result.new(
      true,
      {
        customer_id: 'cus_Q9uqUz6nXQFku2',
        ephemeral_key_secret: 'ek_test_YWNjdF8xTGtSb1lJaFIwZ0llZ0llLG1LbFhsVU9XWHY1SlNyMXRKVzNJb0hyQ2JZam1HY28_007lGgvGaA',
        setup_intent_client_secret: 'seti_1PJb0hIhR0gIegIeZYQQzgpH_secret_Q9uqLuTAvIJQSK1SFS6OaxJMRpe9s7R'
      }
    )
  end

  include_context 'API v2 tokens'

  context 'when user is logged in' do
    before do
      create_setup_intent_service = instance_double(SpreeStripe::CreateSetupIntent)
      allow(SpreeStripe::CreateSetupIntent).to receive(:new).and_return(create_setup_intent_service)
      allow(create_setup_intent_service).to receive(:call).with(gateway: gateway, user: user).and_return(service_response)
    end

    it 'uses the user to create a setup intent' do
      post '/api/v2/storefront/stripe/setup_intents', headers: headers_bearer

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq(
        {
          customer_id: service_response.value[:customer_id],
          ephemeral_key_secret: service_response.value[:ephemeral_key_secret],
          setup_intent_client_secret: service_response.value[:setup_intent_client_secret]
        }.stringify_keys
      )
    end
  end

  context 'when user is not logged in' do
    before { post '/api/v2/storefront/stripe/setup_intents' }

    it_behaves_like 'returns 403 HTTP status'
  end
end
