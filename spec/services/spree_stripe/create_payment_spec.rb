require 'spec_helper'

RSpec.describe SpreeStripe::CreatePayment do
  subject(:create_payment) { described_class.new(order: order, payment_intent: payment_intent, gateway: gateway).call }

  let(:store) { Spree::Store.default }
  let!(:order) { create(:order_with_line_items, store: store) }

  let!(:gateway) { create(:stripe_gateway, *gateway_traits, stores: [order.store]) }
  let(:gateway_traits) { [] }

  let(:payment_intent) { create(:payment_intent, order: order, payment_method: gateway, amount: 30, stripe_id: payment_intent_id) }
  let!(:stripe_customer) { create(:gateway_customer, user: order.user, payment_method: gateway, profile_id: customer_id) }

  let(:payment_intent_event) { SpreeStripe::Events::PaymentIntentEvent.new(event_data: event_data) }

  let(:event_data) do
    {
      'id' => 'evt_3QY76s2ESifGlJez0iBfr0II',
      'object' => 'event',
      'data' => {
        'object' => {
          'id' => payment_intent_id,
          'object' => 'payment_intent',
          'amount' => 4500,
          'currency' => 'usd',
          'customer' => customer_id,
          'latest_charge' => charge_id,
          'metadata' => { 'spree_order_id' => '4ffaad7e-88fc-452a-8f89-24403a0bdca2' },
          'on_behalf_of' => nil,
          'payment_method' => payment_method_id,
          'status' => 'succeeded',
          'transfer_group' => 'R808743511'
        }
      },
      'type' => 'payment_intent.succeeded'
    }
  end

  let(:payment_intent_id) { 'pi_3QY76s2ESifGlJez04sj0cMb' }
  let(:charge_id) { 'ch_3OITmjIhR0gIegIe1eY6FVNu' }
  let(:customer_id) { 'cus_RQdclxFVLH4oau' }
  let(:payment_method_id) { 'pm_1QY4zO2ESifGlJezkHIvUraY' }

  let(:payment) { order.payments.checkout.last }

  it 'creates a payment with passed data' do
    expect(gateway).not_to receive(:create_payment_intent)

    VCR.use_cassette('retrieve_payment_intent_charge') do
      expect { subject }.to change { order.payments.count }.by(1).and change { Spree::CreditCard.count }.by(1)
    end

    expect(subject).to be_a Spree::Payment

    expect(payment.payment_method).to eq gateway
    expect(payment.amount).to eq order.total
    expect(payment.response_code).to eq(payment_intent_id)

    expect(payment.source).to be_a Spree::CreditCard
    expect(payment.source.gateway_payment_profile_id).to eq(payment_method_id)
    expect(payment.source.user).to eq order.user
    expect(payment.source.cc_type).to eq('visa')
    expect(payment.source.last_digits).to eq('4242')
    expect(payment.source.month).to eq(2)
    expect(payment.source.year).to eq(2027)

    expect(payment.avs_response).to eq('Y')
    expect(payment.cvv_response_code).to eq(nil)
  end

  it 'only creates payment once' do
    VCR.use_cassette('retrieve_payment_intent_charge') do
      expect { subject }.to change { order.payments.count }.by(1)
      expect { subject }.not_to change { order.payments.count }
    end
  end
end
