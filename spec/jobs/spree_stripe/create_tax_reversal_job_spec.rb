require 'spec_helper'

RSpec.describe SpreeStripe::CreateTaxReversalJob do
  subject { described_class.new.perform(refund.id) }

  let(:store) { Spree::Store.default }
  let(:user) { create(:user) }
  let!(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
  let!(:stripe_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: 'cus_123') }

  let(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:payment) do
    create(:payment, order: order, payment_method: stripe_gateway, response_code: 'pi_1234567890', amount: order.total,
                     private_metadata: { 'stripe_tax_transaction_id' => 'tax_1234567890' })
  end

  let(:refund) { create(:refund, payment: payment, amount: 10, transaction_id: 're_1234567890') }

  before do
    allow(Stripe::Refund).to receive(:retrieve).and_return(double(amount: 1250))
    allow(Stripe::Tax::Transaction).to receive(:create_reversal).and_return(double(id: 'tax_reversal_1234567890'))
  end

  it 'reverses the tax by the amount actually refunded by Stripe' do
    subject

    expect(Stripe::Tax::Transaction).to have_received(:create_reversal).with(
      {
        mode: 'partial',
        original_transaction: 'tax_1234567890',
        reference: "pi_1234567890-refund-#{refund.id}",
        flat_amount: -1250,
        metadata: { refund: refund.id },
        expand: ['line_items']
      },
      { api_key: stripe_gateway.preferred_secret_key }
    )
  end

  it 'stores the reversal id on the refund' do
    subject

    expect(refund.reload.stripe_tax_reversal_id).to eq('tax_reversal_1234567890')
  end

  context 'when the refund has already been reversed' do
    before { refund.update(stripe_tax_reversal_id: 'tax_reversal_existing') }

    it 'does not reverse it again' do
      subject

      expect(Stripe::Tax::Transaction).not_to have_received(:create_reversal)
      expect(refund.reload.stripe_tax_reversal_id).to eq('tax_reversal_existing')
    end
  end

  context 'when the payment has no recorded tax transaction' do
    before { payment.update(stripe_tax_transaction_id: nil) }

    it 'does not reverse anything' do
      subject

      expect(Stripe::Tax::Transaction).not_to have_received(:create_reversal)
    end
  end

  context 'when the refund was never sent to Stripe' do
    before { refund.update_column(:transaction_id, nil) }

    it 'falls back to the refund amount' do
      subject

      expect(Stripe::Tax::Transaction).to have_received(:create_reversal).with(
        hash_including(flat_amount: -1000),
        anything
      )
    end
  end

  context 'when the Stripe refund cannot be retrieved' do
    before { allow(Stripe::Refund).to receive(:retrieve).and_raise(Stripe::InvalidRequestError.new('nope', nil)) }

    it 'falls back to the refund amount' do
      subject

      expect(Stripe::Tax::Transaction).to have_received(:create_reversal).with(
        hash_including(flat_amount: -1000),
        anything
      )
    end
  end
end
