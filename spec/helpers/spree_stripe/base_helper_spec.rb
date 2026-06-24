require 'spec_helper'

RSpec.describe SpreeStripe::BaseHelper do
  let(:store) { Spree::Store.default }
  let(:gateway) { create(:stripe_gateway, stores: [store]) }
  let(:order) { create(:order_with_line_items, store: store) }

  before do
    allow(helper).to receive(:current_store).and_return(store)
  end

  describe '#current_stripe_gateway' do
    it 'fetches the Stripe gateway for the current store' do
      expect(store).to receive(:stripe_gateway)
      helper.current_stripe_gateway
    end
  end

  describe '#stripe_cart_prefixed_id' do
    it 'returns the cart prefixed if based on the order id' do
      expect(helper.stripe_cart_prefixed_id(order)).to eq("cart_#{Spree::PrefixedId::SQIDS.encode([order.id])}")
    end
  end

  describe '#current_store_publishable_api_key' do
    it "returns the store's active publishable key token" do
      key = create(:api_key, store: store)
      expect(helper.current_store_publishable_api_key).to eq(key.plaintext_token)
    end
  end

  describe '#current_stripe_payment_session' do
    before do
      allow(helper).to receive(:current_stripe_gateway).and_return(gateway)
      helper.instance_variable_set(:@order, order)
    end

    it 'returns the payment session' do
      session = instance_double(Spree::PaymentSessions::Stripe)
      service = instance_double(SpreeStripe::CreatePaymentSession)
      expect(SpreeStripe::CreatePaymentSession).to receive(:new).and_return(service)
      expect(service).to receive(:call).with(order, gateway).and_return(session)

      expect(helper.current_stripe_payment_session).to eq(session)
    end

    context 'when there is no Stripe gateway' do
      let(:gateway) { nil }

      it 'returns no payment session' do
        expect(helper.current_stripe_payment_session).to be_nil
      end
    end
  end
end
