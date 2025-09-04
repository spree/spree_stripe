require 'spec_helper'

module SpreeStripe
  RSpec.describe TaxPresenter do
    describe '#call' do
      let(:store) { Spree::Store.default }
      let(:country) { store.default_country }
      let(:state) { country.states.first || create(:state, country: country, abbr: 'CA') }
      let(:tax_address) do
        create(:address,
               address1: '123 Main St',
               city: 'Los Angeles',
               state: state,
               zipcode: '90210',
               country: country)
      end
      let(:order) do
        create(:order,
               store: store,
               currency: 'USD',
               ship_address: tax_address,
               bill_address: tax_address)
      end
      let(:line_item1) { create(:line_item, order: order, price: 10.00, quantity: 2) }
      let(:line_item2) { create(:line_item, order: order, price: 15.50, quantity: 1) }
      let(:shipment) { create(:shipment, order: order, cost: 5.00) }
      let(:presenter) { described_class.new(order: order) }

      before do
        order.line_items = [line_item1, line_item2]
        order.shipments = [shipment]
      end

      it 'returns the correct structure' do
        result = presenter.call

        expect(result).to be_a(Hash)
        expect(result).to have_key(:currency)
        expect(result).to have_key(:line_items)
        expect(result).to have_key(:customer_details)
        expect(result).to have_key(:shipping_cost)
        expect(result).to have_key(:expand)
      end

      it 'returns the currency in lowercase' do
        result = presenter.call
        expect(result[:currency]).to eq('usd')
      end

      it 'builds line items attributes correctly' do
        result = presenter.call
        line_items = result[:line_items]

        expect(line_items).to be_an(Array)
        expect(line_items.length).to eq(2)

        first_item = line_items.first
        expect(first_item[:reference]).to eq(line_item1.id)
        expect(first_item[:tax_behavior]).to eq(TaxPresenter::TAX_BEHAVIOR)
        expect(first_item[:amount]).to eq(line_item1.display_amount.cents)
        expect(first_item[:quantity]).to eq(line_item1.quantity)

        second_item = line_items.second
        expect(second_item[:reference]).to eq(line_item2.id)
        expect(second_item[:tax_behavior]).to eq(TaxPresenter::TAX_BEHAVIOR)
        expect(second_item[:amount]).to eq(line_item2.display_amount.cents)
        expect(second_item[:quantity]).to eq(line_item2.quantity)
      end

      it 'builds customer details correctly' do
        result = presenter.call
        customer_details = result[:customer_details]

        expect(customer_details[:address_source]).to eq('shipping')
        expect(customer_details[:address][:line1]).to eq(tax_address.address1)
        expect(customer_details[:address][:city]).to eq(tax_address.city)
        expect(customer_details[:address][:state]).to eq(tax_address.state)
        expect(customer_details[:address][:postal_code]).to eq(tax_address.zipcode)
        expect(customer_details[:address][:country]).to eq(tax_address.country_iso)
      end

      it 'builds shipping cost correctly' do
        result = presenter.call
        shipping_cost = result[:shipping_cost]

        expect(shipping_cost[:amount]).to eq(shipment.display_cost.cents)
        expect(shipping_cost[:tax_behavior]).to eq(TaxPresenter::TAX_BEHAVIOR)
        expect(shipping_cost[:tax_code]).to eq(TaxPresenter::SHIPPING_TAX_CODE)
      end

      it 'includes correct expand parameters' do
        result = presenter.call
        expand = result[:expand]

        expect(expand).to be_an(Array)
        expect(expand).to include('line_items.data.tax_breakdown')
        expect(expand).to include('shipping_cost.tax_breakdown')
      end

      context 'when tax address is blank' do
        let(:order) do
          create(:order,
                 currency: 'USD',
                 ship_address: nil,
                 bill_address: nil)
        end

        it 'returns empty address hash' do
          result = presenter.call
          expect(result[:customer_details][:address]).to eq({})
        end
      end

      context 'with multiple shipments' do
        let(:shipment2) { create(:shipment, order: order, cost: 3.50) }

        before do
          order.shipments = [shipment, shipment2]
        end

        it 'calculates total shipping cost correctly' do
          result = presenter.call
          expected_total_cents = (shipment.cost + shipment2.cost) * 100
          expect(result[:shipping_cost][:amount]).to eq(expected_total_cents)
        end
      end

      context 'with different currency' do
        let(:order) { create(:order, currency: 'EUR') }

        it 'returns the currency in lowercase' do
          result = presenter.call
          expect(result[:currency]).to eq('eur')
        end
      end
    end

    describe '#order' do
      let(:order) { create(:order) }
      let(:presenter) { described_class.new(order: order) }

      it 'returns the order' do
        expect(presenter.order).to eq(order)
      end
    end
  end
end
