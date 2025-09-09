require 'spec_helper'

RSpec.describe SpreeStripe::Calculators::StripeTax do
  let(:calculator) { described_class.new }

  let(:store) { Spree::Store.default }
  let!(:gateway) { create(:stripe_gateway, stores: [store]) }

  let(:order) { create(:order_with_line_items, line_items_count: 3, shipment_cost: 10, ship_address: ship_address) }

  let(:ship_address) do
    create(
      :address,
      city: 'Lancaster',
      address1: '3201 North Dallas Avenue',
      postal_code: '75134',
      state: texas_state,
      country: usa_country
    )
  end

  let(:usa_country) { Spree::Country.find_by(iso: 'US') || create(:usa_country) }
  let(:texas_state) { create(:state, name: 'Texas', abbr: 'TX', country: usa_country) }

  before do
    order.line_items[0].update_column(:price, 10)
    order.line_items[1].update_column(:price, 20)
    order.line_items[2].update_column(:price, 30)
  end

  describe '#compute_line_item' do
    subject { calculator.compute_line_item(line_item) }

    let(:line_item) { order.line_items[1] }

    context 'when order is in state for tax calculation' do
      let(:tax_calculation) do
        Stripe::Tax::Calculation.construct_from(
          id: 'taxcalc_1234567890',
          line_items: {
            data: [
              {
                id: 'tax_li_1234567890',
                amount: 2000,
                amount_tax: 160,
                reference: order.line_items[1].id.to_s,
              }
            ]
          }
        )
      end

      before do
        order.update(state: 'payment')
        allow_any_instance_of(SpreeStripe::Gateway).to receive(:create_tax_calculation).and_return(tax_calculation)
      end

      it 'returns the tax amount for the line item' do
        expect(subject).to eq(1.6.to_d)
      end

      it 'persists the tax calculation id in the order' do
        subject
        expect(order.reload.stripe_tax_calculation_id).to eq('taxcalc_1234567890')
      end

      context 'when the line item is not found in the tax calculation' do
        let(:line_item) { order.line_items[0] }

        it 'returns 0' do
          expect(subject).to eq(0.to_d)
        end
      end
    end

    context 'when stripe gateway is not enabled' do
      before { gateway.destroy! }

      it { is_expected.to eq(0.to_d) }
    end

    context 'when order is in cart state' do
      before { order.update(state: 'cart') }

      it { is_expected.to eq(0.to_d) }
    end

    context 'when order is in address state' do
      before { order.update(state: 'address') }

      it { is_expected.to eq(0.to_d) }
    end
  end

  describe '#compute_shipment' do
    subject { calculator.compute_shipment(shipment) }

    let(:shipment) { order.shipments.first }

    context 'when order is in state for tax calculation' do
      let(:tax_calculation) do
        Stripe::Tax::Calculation.construct_from(
          id: 'taxcalc_1234567890',
          shipping_cost: {
            amount: 1000,
            amount_tax: 80
          }
        )
      end

      before do
        order.update(state: 'payment')
        allow_any_instance_of(SpreeStripe::Gateway).to receive(:create_tax_calculation).and_return(tax_calculation)
      end

      it 'returns the tax amount for the shipment' do
        expect(subject).to eq(0.8.to_d)
      end
    end

    context 'when stripe gateway is not enabled' do
      before { gateway.destroy! }

      it { is_expected.to eq(0.to_d) }
    end

    context 'when order is in cart state' do
      before { order.update(state: 'cart') }

      it { is_expected.to eq(0.to_d) }
    end

    context 'when order is in address state' do
      before { order.update(state: 'address') }

      it { is_expected.to eq(0.to_d) }
    end
  end
end
