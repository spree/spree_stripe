require 'spec_helper'

RSpec.describe SpreeStripe::CreateTaxTransactionJob do
  subject { described_class.new.perform(store.id, payment_intent_id, tax_calculation_id) }

  let(:store) { Spree::Store.default }
  let(:payment_intent_id) { 'pi_1234567890' }
  let(:tax_calculation_id) { 'taxcalc_1234567890' }

  before do
    allow(Stripe::Tax::Transaction).to receive(:create_from_calculation)
  end

  context 'when the stripe gateway is enabled' do
    let!(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }

    it 'creates a tax transaction' do
      subject

      expect(Stripe::Tax::Transaction).to have_received(:create_from_calculation).with(
        {
          calculation: tax_calculation_id,
          reference: payment_intent_id,
          expand: ['line_items']
        },
        { api_key: stripe_gateway.preferred_secret_key }
      )
    end
  end

  context 'when the stripe gateway is not enabled' do
    it 'does not create a tax transaction' do
      subject
      expect(Stripe::Tax::Transaction).not_to have_received(:create_from_calculation)
    end
  end
end
