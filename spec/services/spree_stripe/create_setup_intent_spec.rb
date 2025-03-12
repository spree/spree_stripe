require 'spec_helper'

RSpec.describe SpreeStripe::CreateSetupIntent, vcr: true do
  let(:store) { Spree::Store.default }
  let!(:gateway) { create(:stripe_gateway, stores: [store]) }
  let(:saved_customer_id) { 'cus_Q9uqUz6nXQFku2' }

  subject { described_class.call(gateway: gateway, user: user) }

  context 'when user is present' do
    let(:user) { create(:user) }

    context 'when user has saved customer' do
      let!(:customer) { create(:gateway_customer, user: user, profile_id: saved_customer_id, payment_method: gateway) }

      it 'reuses saved customer, creates future payment intent and ephermal key and returns them' do
        subject

        expect(subject).to be_success
        expect(subject.value).to eq(
          {
            customer_id: customer.profile_id,
            ephemeral_key_secret: 'ek_test_YWNjdF8xTGtSb1lJaFIwZ0llZ0llLHpNRndEbEFXdGlQZTJwV1l2WGtXeUlJRlJidVNpeHY_00PkGOSrvo',
            setup_intent_client_secret: 'seti_1PJbXoIhR0gIegIepptgpSqC_secret_Q9vOeLmmJTKurofB3uAZC4cNRtG2ucm'
          }
        )
      end
    end

    context 'when user does not have saved customer' do
      it 'saves the customer , creates future payment intent and ephermal key and returns them' do
        expect { subject }.to change(gateway.gateway_customers, :count).by(1)

        expect(subject).to be_success
        expect(subject.value).to eq(
          {
            customer_id: 'cus_Q9v0APMRnrNbfC',
            ephemeral_key_secret: 'ek_test_YWNjdF8xTGtSb1lJaFIwZ0llZ0llLGpHZnE4c2RNZEtkUWpKTG1yNTVkMFZCUnc4NHl3UDY_00U1Z3E9MD',
            setup_intent_client_secret: 'seti_1PJbAeIhR0gIegIegWP0cPLQ_secret_Q9v0pZGHMjfBZXCotj6Pw5ZOdQ8ttfL'
          }
        )

        saved_customer = gateway.gateway_customers.find_by(user: user)
        expect(saved_customer.profile_id).to eq('cus_Q9v0APMRnrNbfC')
      end
    end
  end
end
