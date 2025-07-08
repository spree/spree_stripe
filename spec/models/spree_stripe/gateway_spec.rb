require 'spec_helper'

RSpec.describe SpreeStripe::Gateway do
  let(:store) { Spree::Store.default }
  let(:gateway) { create(:stripe_gateway, stores: [store]) }
  let(:amount) { 100 }

  describe '#webhook_url' do
    subject { gateway.webhook_url }

    it 'returns the webhook url' do
      expect(subject).to eq("https://#{store.url}/stripe")
    end
  end

  describe '#after_commit :register_domain' do
    subject(:create_gateway) { gateway }

    it 'schedules a job to register the Apple Pay store domain' do
      expect { create_gateway }.to have_enqueued_job(SpreeStripe::RegisterDomainJob).once.with(store.id, 'store')
    end

    context 'with custom domains' do
      let!(:custom_domains) { create_list(:custom_domain, 3, store: store) }

      it 'schedules jobs to register the Apple Pay store and custom domains' do
        expect do
          create_gateway
        end.to have_enqueued_job(SpreeStripe::RegisterDomainJob).exactly(4).times
      end
    end

    context 'on update' do
      before { create_gateway }

      it 'does nothing' do
        expect { gateway.update!(name: 'test') }.not_to have_enqueued_job(SpreeStripe::RegisterDomainJob)
      end
    end
  end

  describe '#create_payment_intent' do
    subject { gateway.create_payment_intent(amount, order) }

    let(:order) { create(:order_with_line_items) }

    let(:payment_intent_id) { 'pi_3QXmfC2ESifGlJez0qSmz8Vf' }
    let(:customer_id) { 'cus_RQdxueQXRuXVxx' }

    it 'creates payment intent with a new customer' do
      VCR.use_cassette('create_payment_intent') do
        expect { subject }.to change(Spree::GatewayCustomer, :count).by(1)

        expect(subject.success?).to be(true)
        expect(subject.authorization).to eq(payment_intent_id)

        expect(gateway.gateway_customers.last.user).to eq(order.user)
        expect(gateway.gateway_customers.last.profile_id).to eq(customer_id)
      end
    end

    context 'with a customer' do
      let!(:customer) { create(:gateway_customer, user: order.user, payment_method: gateway) }

      it 'creates payment intent with an existing customer' do
        VCR.use_cassette('create_payment_intent') do
          expect { subject }.to_not change(Spree::GatewayCustomer, :count)

          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
        end
      end
    end

    context 'when off_session is true' do
      subject { gateway.create_payment_intent(amount, order, off_session: true, payment_method_id: payment_method_id) }

      let!(:gateway_customer) { create(:gateway_customer, user: order.user, profile_id: customer_id, payment_method: gateway) }

      let(:customer_id) { 'cus_RQdclxFVLH4oau' }
      let(:payment_method_id) { 'pm_1QXmPJ2ESifGlJezC2py6ZqS' }
      let(:payment_intent_id) { 'pi_3QY1WI2ESifGlJez0JGP7vpi' }

      it 'creates payment intent' do
        VCR.use_cassette('create_payment_intent_off_session') do
          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
          expect(subject.params['status']).to eq('succeeded')
          expect(subject.params['payment_method']).to eq(payment_method_id)
        end
      end
    end

    context 'when shipping address is invalid' do
      let(:order) do
        build(
          :order_with_line_items,
          ship_address: build(:address, address1: nil),
          store: Spree::Store.default
        )
      end

      let(:payment_intent_id) { 'pi_3QY1a32ESifGlJez0k9YRZnS' }

      it 'creates the payment intent without shipping address' do
        VCR.use_cassette('create_payment_intent_invalid_address') do
          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
          expect(subject.params['shipping']).to be_nil
        end
      end
    end
  end

  describe '#update_payment_intent' do
    subject { gateway.update_payment_intent(payment_intent_id, amount, order, payment_method_id) }

    let!(:customer) { create(:gateway_customer, user: order.user, payment_method: gateway, profile_id: customer_id) }
    let(:order) { create(:completed_order_with_totals, store: store) }

    let(:amount) { 4000 }
    let(:payment_method_id) { nil }

    let(:customer_id) { 'cus_RQdclxFVLH4oau' }
    let(:payment_intent_id) { 'pi_3QY2qD2ESifGlJez0VuzXjwK' }

    context 'when the amount is different' do
      let(:amount) { 6000 }

      it 'updates the payment intent with a new amount' do
        VCR.use_cassette('update_payment_intent_new_amount') do
          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
          expect(subject.params['amount']).to eq(6000)
        end
      end

      context 'when shipping address is invalid' do
        let(:amount) { 7000 }

        let(:order) do
          build(
            :order_with_line_items,
            ship_address: build(:address, address1: nil),
            store: Spree::Store.default
          )
        end

        it 'updates the payment intent without shipping address' do
          VCR.use_cassette('update_payment_intent_invalid_address') do
            expect(subject.success?).to be(true)
            expect(subject.authorization).to eq(payment_intent_id)
            expect(subject.params['amount']).to eq(7000)
          end
        end
      end
    end

    context 'when the shipping address is different' do
      let(:address) do
        create(
          :address,
          firstname: 'Jane',
          lastname: 'Zoe',
          address1: '100 California Street',
          address2: nil,
          city: 'San Francisco',
          zipcode: '94111',
          state: california_state,
          country: usa_country
        )
      end

      let(:usa_country) { Spree::Country.find_by(iso: 'US') || create(:usa_country) }
      let(:california_state) { create(:state, name: 'California', abbr: 'CA', country: usa_country) }

      before do
        order.update!(shipping_address: address)
      end

      it 'it updates the payment intent with a new address' do
        VCR.use_cassette('update_payment_intent_new_address') do
          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)

          expect(subject.params['shipping']['name']).to eq('Jane Zoe')
          expect(subject.params['shipping']['address']).to eq(
            'city' => 'San Francisco',
            'country' => 'US',
            'line1' => '100 California Street',
            'line2' => nil,
            'postal_code' => '94111',
            'state' => 'CA'
          )
        end
      end
    end

    context 'when giving a payment method' do
      let(:payment_method_id) { 'pm_1QXmPJ2ESifGlJezC2py6ZqS' }

      it 'it updates the payment intent with a payment method' do
        VCR.use_cassette('update_payment_intent_payment_method') do
          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
          expect(subject.params['payment_method']).to eq(payment_method_id)
        end
      end
    end

    context 'when the currency is different' do
      before do
        order.update!(currency: 'PLN')
      end

      it 'it updates the payment intent with a new currency' do
        VCR.use_cassette('update_payment_intent_new_currency') do
          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
          expect(subject.params['currency']).to eq('pln')
        end
      end
    end
  end

  describe '#cancel' do
    subject { gateway.cancel(payment_intent_id, payment) }

    let!(:refund_reason) { Spree::RefundReason.first || create(:default_refund_reason) }

    context 'when payment is completed' do
      let!(:order) { create(:order, total: 10) }
      let!(:customer) { create(:gateway_customer, user: order.user, payment_method: gateway) }

      let!(:payment) { create(:payment, state: 'completed', order: order, payment_method: gateway, amount: 10.0, response_code: payment_intent_id) }
      let!(:refund) { create(:refund, payment: payment, amount: 2.0) }

      let(:payment_intent_id) { 'pi_3QXmL12ESifGlJez0v0B8tUn' }
      let(:refund_id) { 're_3QXmL12ESifGlJez0GcOBHng' }

      it 'creates a refund with credit_allowed_amount' do
        VCR.use_cassette('create_refund') do
          expect { subject }.to change(Spree::Refund, :count).by(1)

          expect(payment.refunds.last.amount).to eq(8.0)

          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)

          expect(subject.params['id']).to eq(refund_id)
          expect(subject.params['status']).to eq('succeeded')
          expect(subject.params['payment_intent']).to eq(payment_intent_id)
          expect(subject.params['object']).to eq('refund')
          expect(subject.params['amount']).to eq(800)
        end
      end

      context 'if amount to refund is zero' do
        let!(:refund) { create(:refund, payment: payment, amount: payment.amount) }

        it 'does not create refund' do
          expect { subject }.not_to change(Spree::Refund, :count)

          expect(subject.success?).to be true
          expect(subject.authorization).to eq(payment_intent_id)
        end
      end
    end

    context 'when payment is not completed' do
      let!(:payment) { create(:payment, response_code: payment_intent_id) }

      let(:payment_intent_id) { 'pi_3QY1o72ESifGlJez06ZbKHjy' }

      it 'cancels the payment intent' do
        VCR.use_cassette('cancel_payment_intent') do
          expect { subject }.not_to change(Spree::Refund, :count)

          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
          expect(subject.params['status']).to eq('canceled')
        end
      end
    end
  end

  describe '#credit' do
    subject { gateway.credit(amount_in_cents, nil, payment_intent_id, {}) }

    let(:amount_in_cents) { 800 }
    let(:payment_intent_id) { 'pi_3QXmL12ESifGlJez0v0B8tUn' }

    let(:refund_id) { 're_3QXmL12ESifGlJez0GcOBHng' }

    it 'refunds some of the payment amount' do
      VCR.use_cassette('create_refund') do
        expect(subject.success?).to be(true)
        expect(subject.authorization).to eq(refund_id)

        expect(subject.params['id']).to eq(refund_id)
        expect(subject.params['status']).to eq('succeeded')
        expect(subject.params['payment_intent']).to eq(payment_intent_id)
        expect(subject.params['object']).to eq('refund')
        expect(subject.params['amount']).to eq(800)
      end
    end
  end

  describe '#purchase' do
    subject { gateway.purchase(amount_in_cents, credit_card, { order_id: order_id }) }

    let(:amount_in_cents) { 1000 }
    let(:order_id) { "#{order.number}-#{payment.number}" }

    let!(:order) { create(:completed_order_with_totals, number: 'R111098765') }

    let!(:customer) { create(:gateway_customer, user: order.user, profile_id: customer_id, payment_method: gateway) }
    let!(:credit_card) { create(:credit_card, gateway_payment_profile_id: payment_method_id, payment_method: gateway) }

    let!(:payment) { create(:payment, number: 'ABC1DEF2', amount: 110, payment_method: gateway, order: order, source: credit_card, response_code: nil) }

    let(:customer_id) { 'cus_RQdclxFVLH4oau' }
    let(:payment_method_id) { 'pm_1QXmPJ2ESifGlJezC2py6ZqS' }
    let(:payment_intent_id) { 'pi_3QY1y22ESifGlJez12haN8ah' }

    it 'successfully creates a payment intent' do
      VCR.use_cassette('create_payment_intent_with_payment_method') do
        expect(subject.success?).to be true

        expect(subject.authorization).to eq(payment_intent_id)
        expect(subject.params['status']).to eq('succeeded')
        expect(subject.params['amount']).to eq(amount_in_cents)
        expect(subject.params['payment_method']).to eq(payment_method_id)
        expect(subject.params['customer']).to eq(customer_id)
        expect(subject.params['transfer_group']).to eq(order.number)

        expect(payment.reload.response_code).to eq(payment_intent_id)
        expect(payment.state).to eq('checkout')
      end
    end

    context 'when order or payment is missing' do
      let(:order_id) { 'missing' }

      it 'returns failure' do
        expect(subject.success?).to be(false)
        expect(payment.reload.state).to eq 'checkout'
      end
    end
  end

  describe 'being a provider' do
    let(:provider_methods) do
      [:authorize, :purchase, :capture, :void, :credit]
    end

    it 'implements provider methods and does not cause infinite loop' do
      provider_methods.each do |method|
        expect(gateway).to respond_to method
        expect { gateway.send(method) }.not_to raise_error SystemStackError
      end
    end
  end
end
