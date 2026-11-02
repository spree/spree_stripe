require 'spec_helper'

RSpec.describe SpreeStripe::RefundDecorator do
  describe 'after_create' do
    subject { create(:refund, payment: payment, amount: 10, transaction_id: 're_1234567890') }

    let(:store) { Spree::Store.default }
    let(:user) { create(:user) }
    let(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
    let!(:stripe_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: 'cus_123') }

    let(:order) { create(:order_with_line_items, store: store, user: user) }
    let(:payment) do
      create(:payment, order: order, payment_method: stripe_gateway, response_code: 'pi_1234567890', amount: order.total,
                       private_metadata: { 'stripe_tax_transaction_id' => tax_transaction_id })
    end

    let(:tax_transaction_id) { 'tax_1234567890' }

    it 'reverses the recorded tax' do
      expect { subject }.to have_enqueued_job(SpreeStripe::CreateTaxReversalJob)
    end

    context 'when the payment has no recorded tax transaction' do
      let(:tax_transaction_id) { nil }

      it 'does not reverse anything' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CreateTaxReversalJob)
      end
    end

    context 'when the refund has already been reversed' do
      subject do
        create(:refund, payment: payment, amount: 10, transaction_id: 're_1234567890',
                        private_metadata: { 'stripe_tax_reversal_id' => 'tax_reversal_1' })
      end

      it 'does not reverse it again' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CreateTaxReversalJob)
      end
    end

    context 'when the payment is not a Stripe one' do
      let(:payment) { create(:payment, order: order, amount: order.total) }

      it 'does not reverse anything' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CreateTaxReversalJob)
      end
    end
  end
end
