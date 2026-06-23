require 'spec_helper'

RSpec.describe SpreeStripe::WebhookHandlers::PaymentIntentPaymentFailed do
  describe '#call' do
    subject { described_class.new.call(event) }

    let(:store) { Spree::Store.default }
    let(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
    let(:stripe_id) { 'pi_failed_123' }

    let(:event) do
      double(
        data: double(
          object: double(
            id: stripe_id,
            object: 'payment_intent'
          )
        )
      )
    end

    context 'with a payment session' do
      let!(:order) { create(:completed_order_with_totals, store: store) }
      let!(:payment_session) do
        create(:stripe_payment_session,
               order: order,
               payment_method: stripe_gateway,
               external_id: stripe_id)
      end

      it 'transitions the payment session to failed' do
        subject
        expect(payment_session.reload.status).to eq('failed')
      end

      it 'cancels the order' do
        expect { subject }.to change { order.reload.state }.from('complete').to('canceled')
      end

      context 'when the payment session is already completed' do
        before { payment_session.update_column(:status, 'completed') }

        it 'does not transition the session' do
          subject
          expect(payment_session.reload.status).to eq('completed')
        end
      end

      context 'when the order is already canceled' do
        before { order.cancel! }

        it 'does not cancel again' do
          expect { subject }.not_to change { order.reload.state }
        end
      end
    end

    context 'with neither payment session nor payment intent' do
      it 'does nothing' do
        expect { subject }.not_to raise_error
      end
    end
  end
end
