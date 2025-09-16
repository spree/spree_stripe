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

  let(:order) { create(:order) }
  let(:customer) { 'cus_123' }
  let(:amount) { 100 }
  let(:payment_method_id) { nil }
  let(:ship_address) { nil }

  let(:store) { Spree::Store.default }

  let(:store_name) { 'Test Store' }
  let(:statement_descriptor) { "#{order.number} #{store_name}" }

  before do
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
          statement_descriptor_suffix: statement_descriptor,
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
            statement_descriptor_suffix: statement_descriptor,
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
          statement_descriptor_suffix: statement_descriptor,
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
    let(:order) { create(:order, user: nil, email: 'john@snow.org') }

    it 'returns a payload with new payment method' do
      expect(subject).to eq(
        {
          amount: amount,
          customer: customer,
          currency: order.currency,
          statement_descriptor_suffix: statement_descriptor,
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
          statement_descriptor_suffix: statement_descriptor,
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

    context 'for a descriptor of 22 characters' do
      let(:store_name) { 'ABCDE Store' }
      it { is_expected.to eq("#{order.number} ABCDE STORE") }
    end

    context 'for a long store name' do
      let(:store_name) { 'Very Long Store Name' }

      it { is_expected.to eq("#{order.number} VERY LONG S") }
      it { is_expected.to have_attributes(length: 22) }
    end
  end
end
