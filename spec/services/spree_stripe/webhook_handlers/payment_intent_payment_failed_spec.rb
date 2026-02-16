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

      it 'does not look up legacy payment intents' do
        expect(SpreeStripe::PaymentIntent).not_to receive(:find_by)
        subject
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

    context 'with a legacy payment intent' do
      let!(:order) { create(:completed_order_with_totals, store: store) }
      let!(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, stripe_id: stripe_id) }

      it 'cancels the order' do
        expect { subject }.to change { order.reload.state }.from('complete').to('canceled')
      end
    end

    context 'with neither payment session nor payment intent' do
      it 'does nothing' do
        expect { subject }.not_to raise_error
      end
    end
  end
end
