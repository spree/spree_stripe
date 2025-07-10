require 'spec_helper'

RSpec.describe SpreeStripe::UpdateCustomer do
  subject { described_class.new.call(user: user) }

  let(:user) { create(:user) }
  let(:store) { Spree::Store.default }

  before do
    allow(Stripe::Customer).to receive(:update).and_return(double(id: 'cus_123'))
  end

  context 'when user has a Stripe gateway customer' do
    let!(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
    let!(:gateway_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: 'cus_123') }

    it 'updates the Stripe customer' do
      subject
      expect(Stripe::Customer).to have_received(:update).with('cus_123', anything)
    end

    context 'when user has no Stripe gateway customers' do
      let!(:credit_card_payment_method) { create(:credit_card_payment_method, stores: [store]) }
      let!(:credit_card_gateway_customer) { create(:gateway_customer, user: user, payment_method: credit_card_payment_method, profile_id: 'other_123') }

      let(:gateway_customer) { nil }

      it 'does not update the Stripe customer' do
        subject
        expect(Stripe::Customer).not_to have_received(:update)
      end
    end
  end

  context 'when user has no gateway customers at all' do
    it 'does not update the Stripe customer' do
      subject
      expect(Stripe::Customer).not_to have_received(:update)
    end
  end
end
