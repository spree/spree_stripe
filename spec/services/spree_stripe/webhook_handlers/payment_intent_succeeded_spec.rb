require 'spec_helper'

RSpec.describe SpreeStripe::WebhookHandlers::PaymentIntentSucceeded do
  describe '#call' do
    subject { described_class.new.call(event) }

    let(:store) { Spree::Store.default }
    let(:order) { create(:order_with_line_items, store: store) }
    let(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
    let(:payment_intent_id) { 'pi_3Kf5vdDFyWwdfZQ10kAY6fo0' }

    let(:event) do
      Stripe::Event.construct_from(
        {
          id: 'evt_2Zj5zzFU3a9abcZ1aYYYaaZ1',
          object: 'event',
          api_version: '2020-08-27',
          created: 1_633_887_337,
          data: {
            object: {
              id: payment_intent_id,
              object: 'payment_intent',
              amount: 3149,
              amount_received: 3149,
              currency: 'usd',
              status: 'succeeded',
              statement_descriptor_suffix: order.number,
              transfer_group: order.number,
              metadata: { spree_order_id: order.id }
            }
          }
        }
      )
    end

    context 'with a payment session' do
      let!(:payment_session) do
        create(:stripe_payment_session,
               order: order,
               payment_method: stripe_gateway,
               external_id: payment_intent_id)
      end

      it 'enqueues the CompleteOrderFromSessionJob' do
        expect { subject }.to have_enqueued_job(SpreeStripe::CompleteOrderFromSessionJob).with(payment_session.id)
      end

      it 'does not enqueue the legacy CompleteOrderJob' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CompleteOrderJob)
      end
    end

    context 'with a legacy payment intent' do
      let!(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, stripe_id: payment_intent_id) }

      it 'enqueues the legacy CompleteOrderJob' do
        expect { subject }.to have_enqueued_job(SpreeStripe::CompleteOrderJob).with(payment_intent.id)
      end

      it 'does not enqueue CompleteOrderFromSessionJob' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CompleteOrderFromSessionJob)
      end
    end

    context 'with neither payment session nor payment intent' do
      it 'does not enqueue CompleteOrderFromSessionJob' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CompleteOrderFromSessionJob)
      end

      it 'does not enqueue CompleteOrderJob' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CompleteOrderJob)
      end
    end

    context 'when both payment session and legacy payment intent exist' do
      let!(:payment_session) do
        create(:stripe_payment_session,
               order: order,
               payment_method: stripe_gateway,
               external_id: payment_intent_id)
      end
      let!(:legacy_payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, stripe_id: payment_intent_id) }

      it 'prefers the payment session' do
        expect { subject }.to have_enqueued_job(SpreeStripe::CompleteOrderFromSessionJob).with(payment_session.id)
      end

      it 'does not enqueue the legacy job' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CompleteOrderJob)
      end
    end
  end
end
