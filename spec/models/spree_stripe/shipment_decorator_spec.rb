require 'spec_helper'

RSpec.describe SpreeStripe::ShipmentDecorator do
  describe 'after_transition to :shipped' do
    subject { shipment.ship! }

    let(:store) { Spree::Store.default }
    let(:order) { create(:order_ready_to_ship, payment_intents: payment_intents) }

    let(:payment_intents) { [create(:payment_intent, stripe_id: payment_intent_id)] }
    let(:payment_intent_id) { 'pi_1234567890' }
    let(:tax_calculation_id) { 'taxcalc_1234567890' }

    let(:shipment) { order.shipments.first }

    before do
      order.update(stripe_tax_calculation_id: tax_calculation_id)
    end

    context 'when the shipment is fully shipped' do
      it 'creates a tax transaction' do
        expect { subject }.to have_enqueued_job(SpreeStripe::CreateTaxTransactionJob).with(
          store.id, payment_intent_id, tax_calculation_id
        )
      end

      context 'when the shipment order has no stripe tax calculation id' do
        let(:tax_calculation_id) { nil }

        it 'does not create a tax transaction' do
          expect { subject }.not_to have_enqueued_job(SpreeStripe::CreateTaxTransactionJob)
        end
      end

      context 'when the shipment order has no payment intents' do
        let(:payment_intents) { [] }

        it 'does not create a tax transaction' do
          expect { subject }.not_to have_enqueued_job(SpreeStripe::CreateTaxTransactionJob)
        end
      end
    end

    context 'when the shipment is not fully shipped' do
      let!(:other_shipment) { create(:shipment, order: order, state: 'ready') }

      it 'does not create a tax transaction' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::CreateTaxTransactionJob)
      end
    end
  end
end
