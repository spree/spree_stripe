require 'spec_helper'

RSpec.describe SpreeStripe::WebhookHandlers::SetupIntentSucceeded do
  describe '#call' do
    subject { described_class.new.call(event) }

    let(:store) { Spree::Store.default }
    let(:user) { create(:user) }
    let(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
    let!(:gateway_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: customer_id) }
    let(:customer_id) { 'cus_123456789' }
    let(:payment_method_id) { 'pm_123456789' }

    let(:event) do
      Stripe::Event.construct_from(
        {
          id: 'evt_123456789',
          object: 'event',
          api_version: '2020-08-27',
          created: 1_633_887_337,
          data: {
            object: {
              id: 'seti_123456789',
              object: 'setup_intent',
              customer: customer_id,
              payment_method: payment_method_id,
              status: 'succeeded'
            }
          }
        }
      )
    end

    let(:stripe_payment_method) do
      Stripe::PaymentMethod.construct_from(
        {
          id: payment_method_id,
          object: 'payment_method',
          billing_details: {
            name: 'John Doe',
            email: 'john@example.com'
          },
          card: {
            brand: 'visa',
            exp_month: 12,
            exp_year: 2025,
            last4: '4242'
          },
          type: 'card'
        }
      )
    end

    let(:credit_card) { create(:credit_card, user: user, payment_method: stripe_gateway, gateway_payment_profile_id: payment_method_id) }
    let(:error_handler) { instance_double(Spree::Dependencies.error_handler.constantize) }

    before do
      allow(Stripe::PaymentMethod).to receive(:retrieve).with(
        payment_method_id,
        { api_key: stripe_gateway.preferred_secret_key }
      ).and_return(stripe_payment_method)
    end

    context 'when gateway customer exists' do
      it 'creates a new source for the user' do
        expect(SpreeStripe::CreateSource).to receive(:new).with(
          payment_method_details: stripe_payment_method,
          payment_method_id: payment_method_id,
          billing_details: stripe_payment_method.billing_details,
          gateway: stripe_gateway,
          user: user
        ).and_call_original

        expect { subject }.to change(Spree::CreditCard, :count).by(1)

        credit_card = Spree::CreditCard.last
        expect(credit_card).to have_attributes(
          user: user,
          payment_method: stripe_gateway,
          gateway_payment_profile_id: payment_method_id,
          month: 12,
          year: 2025,
          last_digits: '4242',
          name: 'John Doe',
          brand: 'visa'
        )
      end

      context 'when Stripe::PaymentMethod.retrieve fails' do
        let(:stripe_error) { Stripe::StripeError.new('Payment method not found') }

        before do
          allow(Stripe::PaymentMethod).to receive(:retrieve).and_raise(stripe_error)
          allow(Spree::ErrorHandler).to receive(:new).and_return(error_handler)
          allow(error_handler).to receive(:call)
        end

        it 'handles the error and does not create a source' do
          expect { subject }.not_to change(Spree::CreditCard, :count)

          expect(error_handler).to have_received(:call).with(
            exception: stripe_error,
            opts: {
              report_context: { event: event },
              user: user
            }
          )
        end
      end
    end

    context 'when gateway customer does not exist' do
      before { gateway_customer.destroy }

      it 'does not create a source' do
        expect(SpreeStripe::CreateSource).not_to receive(:new)
        expect { subject }.not_to change(Spree::CreditCard, :count)
      end
    end

    context 'when user does not exist' do
      before { user.destroy }

      it 'does not create a source' do
        expect(SpreeStripe::CreateSource).not_to receive(:new)
        expect { subject }.not_to change(Spree::CreditCard, :count)
      end
    end
  end
end
