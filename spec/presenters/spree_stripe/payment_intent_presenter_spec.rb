require 'spec_helper'

RSpec.describe SpreeStripe::PaymentIntentPresenter do
  subject { presenter.call }

  let(:presenter) do
    described_class.new(
      amount: amount,
      order: order,
      customer: customer,
      payment_method_id: payment_method_id
    )
  end
  let(:order_number) { 'R123456789' }

  let(:order) { create(:order, number: order_number) }
  let(:customer) { 'cus_123' }
  let(:amount) { 100 }
  let(:payment_method_id) { nil }
  let(:ship_address) { nil }

  let(:store) { Spree::Store.default }

  let(:statement_descriptor_stub) { double(SpreeStripe::StatementDescriptorSuffixPresenter, call: statement_descriptor_prefix) }
  let(:store_name) { 'Test Store' }
  let(:statement_descriptor_prefix) { 'ORDER123' }

  before do
    allow(SpreeStripe::StatementDescriptorSuffixPresenter).to receive(:new).with(order_description: order.number).and_return(statement_descriptor_stub)
    Spree::Config[:geocode_addresses] = false
    store.update!(name: store_name)
  end

  after do
    Spree::Config[:geocode_addresses] = true
  end

  context 'when payment_method_id is present' do
    let(:payment_method_id) { 'pm_123' }

    it 'returns a payload with saved payment method' do
      expect(subject).to eq(
        {
          amount: amount,
          customer: customer,
          currency: order.currency,
          statement_descriptor_suffix: statement_descriptor_prefix,
          automatic_payment_methods: {
            enabled: true
          },
          transfer_group: order.number,
          metadata: {
            spree_order_id: order.id
          },
          payment_method: payment_method_id,
          off_session: false,
          confirm: false
        }
      )
    end

    context 'when off_session is true' do
      let(:presenter) do
        described_class.new(
          amount: amount,
          order: order,
          customer: customer,
          payment_method_id: payment_method_id,
          off_session: true
        )
      end

      it 'returns a payload with off_session and confirm set to true' do
        expect(subject).to eq(
          {
            amount: amount,
            customer: customer,
            currency: order.currency,
            statement_descriptor_suffix: statement_descriptor_prefix,
            automatic_payment_methods: {
              enabled: true
            },
            transfer_group: order.number,
            metadata: {
              spree_order_id: order.id
            },
            payment_method: payment_method_id,
            off_session: true,
            confirm: true
          }
        )
      end
    end
  end

  context 'when payment_method_id is not present' do
    it 'returns a payload with new payment method' do
      expect(subject).to eq(
        {
          amount: amount,
          customer: customer,
          currency: order.currency,
          statement_descriptor_suffix: statement_descriptor_prefix,
          automatic_payment_methods: {
            enabled: true
          },
          transfer_group: order.number,
          metadata: {
            spree_order_id: order.id
          },
          payment_method_options: {
            card: {
              setup_future_usage: 'off_session'
            }
          },
        }
      )
    end
  end

  context 'order without a user' do
    let(:order) { create(:order, user: nil, email: 'john@snow.org', number: order_number) }

    it 'returns a payload with new payment method' do
      expect(subject).to eq(
        {
          amount: amount,
          customer: customer,
          currency: order.currency,
          statement_descriptor_suffix: statement_descriptor_prefix,
          automatic_payment_methods: {
            enabled: true
          },
          transfer_group: order.number,
          metadata: {
            spree_order_id: order.id
          },
          payment_method_options: {
            card: {
              setup_future_usage: 'off_session'
            }
          },
        }
      )
    end
  end

  context 'when ship_address is present' do
    let(:ship_address) { create(:address) }

    before do
      allow(order).to receive(:ship_address).and_return(ship_address)
    end

    it 'returns a payload with shipping address' do
      expect(subject).to eq(
        {
          amount: amount,
          customer: customer,
          currency: order.currency,
          statement_descriptor_suffix: statement_descriptor_prefix,
          automatic_payment_methods: {
            enabled: true
          },
          transfer_group: order.number,
          metadata: {
            spree_order_id: order.id
          },
          payment_method_options: {
            card: {
              setup_future_usage: 'off_session'
            }
          },
          shipping: {
            address: {
              city: ship_address.city,
              country: ship_address.country_iso,
              line1: ship_address.address1,
              line2: ship_address.address2,
              postal_code: ship_address.zipcode,
              state: ship_address.state_abbr
            },
            name: ship_address.full_name
          }
        }
      )
    end
  end

  describe 'statement descriptor' do
    subject(:statement_descriptor_suffix) { presenter.call[:statement_descriptor_suffix] }

    context 'with stubbed statement descriptor presenter' do


      it 'calls the statement descriptor presenter with valid params' do
        expect(statement_descriptor_stub).to receive(:call)

        subject
      end
    end
  end
end
