require 'spec_helper'

RSpec.describe SpreeStripe::CreateTaxTransactionJob do
  subject { described_class.new.perform(payment.id) }

  let(:store) { Spree::Store.default }
  let!(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }

  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items, store: store, user: user) }
  let!(:stripe_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: 'cus_123') }

  let(:payment) do
    create(:payment, order: order, payment_method: stripe_gateway, response_code: payment_intent_id, amount: order.total)
  end

  let(:payment_intent_id) { 'pi_1234567890' }
  let(:tax_calculation_id) { 'taxcalc_1234567890' }

  before do
    order.update(stripe_tax_calculation_id: tax_calculation_id)
    allow(Stripe::Tax::Transaction).to receive(:create_from_calculation).and_return(double(id: 'tax_1234567890'))
  end

  it 'creates a tax transaction from the order calculation' do
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

  it 'stores the resulting transaction id on the payment' do
    subject

    expect(payment.reload.stripe_tax_transaction_id).to eq('tax_1234567890')
  end

  context 'when the transaction has already been recorded' do
    before { payment.update(stripe_tax_transaction_id: 'tax_existing') }

    it 'does not record it a second time' do
      subject

      expect(Stripe::Tax::Transaction).not_to have_received(:create_from_calculation)
      expect(payment.reload.stripe_tax_transaction_id).to eq('tax_existing')
    end
  end

  context 'when the order has no tax calculation' do
    let(:tax_calculation_id) { nil }

    it 'does not create a tax transaction' do
      subject

      expect(Stripe::Tax::Transaction).not_to have_received(:create_from_calculation)
    end
  end

  context 'when the payment is not a Stripe one' do
    let(:payment) { create(:payment, order: order, response_code: payment_intent_id, amount: order.total) }

    it 'does not create a tax transaction' do
      subject

      expect(Stripe::Tax::Transaction).not_to have_received(:create_from_calculation)
    end
  end
end
