require 'spec_helper'

RSpec.describe SpreeStripe::OrderCompletedSubscriber do
  include ActiveJob::TestHelper

  describe '.subscription_patterns' do
    it 'subscribes to order.completed event' do
      expect(described_class.subscription_patterns).to include('order.completed')
    end
  end

  describe '.event_handlers' do
    it 'routes order.completed to attach_customer_to_credit_card' do
      expect(described_class.event_handlers['order.completed']).to eq(:attach_customer_to_credit_card)
    end
  end

  describe '#attach_customer_to_credit_card' do
    let(:store) { Spree::Store.default }
    let(:user) { create(:user) }
    let(:order) { create(:completed_order_with_totals, store: store, user: user) }
    let(:subscriber) { described_class.new }

    let(:event) do
      Spree::Event.new(
        name: 'order.completed',
        payload: { 'id' => order.id }
      )
    end

    it 'enqueues AttachCustomerToCreditCardJob with order_id' do
      expect {
        subscriber.attach_customer_to_credit_card(event)
      }.to have_enqueued_job(SpreeStripe::AttachCustomerToCreditCardJob).with(order.id)
    end

    context 'when order_id is missing' do
      let(:event) do
        Spree::Event.new(
          name: 'order.completed',
          payload: {}
        )
      end

      it 'does not enqueue any jobs' do
        expect {
          subscriber.attach_customer_to_credit_card(event)
        }.not_to have_enqueued_job(SpreeStripe::AttachCustomerToCreditCardJob)
      end
    end

    context 'when order_id is blank' do
      let(:event) do
        Spree::Event.new(
          name: 'order.completed',
          payload: { 'id' => '' }
        )
      end

      it 'does not enqueue any jobs' do
        expect {
          subscriber.attach_customer_to_credit_card(event)
        }.not_to have_enqueued_job(SpreeStripe::AttachCustomerToCreditCardJob)
      end
    end
  end
end
