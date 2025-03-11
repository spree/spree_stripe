require 'spec_helper'

RSpec.describe SpreeStripe::PaymentIntent do
  let(:store) { Spree::Store.default }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
  let!(:stripe_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: 'cus_123') }

  subject { build(:payment_intent, order: order, payment_method: stripe_gateway) }

  describe 'Callbacks' do
    describe '#set_amount_from_order' do
      it 'sets amount from order' do
        subject.valid?
        expect(subject.amount).to eq(order.total_minus_store_credits)
      end
    end

    describe '#update_stripe_payment_intent' do
      subject { create(:payment_intent, order: order, payment_method: stripe_gateway, stripe_id: 'pi_123') }

      it 'updates the stripe payment intent' do
        expect(stripe_gateway).to receive(:update_payment_intent).with(subject.stripe_id, 11_500, order, subject.stripe_payment_method_id)
        subject.update!(amount: 115)
      end
    end
  end

  describe '#find_or_create_payment!' do
    let(:payment_intent_id) { 'pi_3QY76s2ESifGlJez04sj0cMb' }

    before do
      subject.stripe_id = payment_intent_id
      subject.save!
    end

    context "when payment doesn't exist", vcr: { cassette_name: 'retrieve_payment_intent_charge' } do
      it "creates a payment if it doesn't exist" do
        expect { subject.find_or_create_payment! }.to change(Spree::Payment, :count).by(1)

        subject.reload
        expect(subject.payment).to be_a(Spree::Payment)
        expect(subject.payment.amount).to eq(subject.amount)
        expect(subject.payment.payment_method).to eq(subject.payment_method)
        expect(subject.payment.response_code).to eq(subject.stripe_id)
      end
    end

    it "finds a payment if it exists" do
      payment = create(:payment, order: order, payment_method: stripe_gateway, amount: subject.amount, response_code: subject.stripe_id)
      expect { subject.find_or_create_payment! }.not_to change(Spree::Payment, :count)
      expect(subject.payment).to eq(payment)
    end
  end
end
