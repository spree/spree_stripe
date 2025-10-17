require 'spec_helper'

RSpec.describe SpreeStripe::Gateway do
  let(:store) { Spree::Store.default }
  let(:gateway) { create(:stripe_gateway, stores: [store]) }
  let(:amount) { 100 }

  describe '#webhook_url' do
    subject { gateway.webhook_url }

    it 'returns the webhook url' do
      expect(subject).to eq("https://#{store.url}/stripe/")
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

  describe '#create_customer' do
    subject { gateway.create_customer(order: order, user: user) }

    let(:order) { create(:order_with_line_items, user: user, bill_address: bill_address, email: 'test@example.com') }
    let(:user) { create(:user, email: 'test@example.com', first_name: 'Jane', last_name: 'Moe', bill_address: user_bill_address) }

    let(:bill_address) do
      create(
        :address,
        city: 'San Francisco',
        address1: '100 California Street',
        address2: 'Apt 1',
        postal_code: '94111',
        state: california_state,
        country: usa_country,
        firstname: 'John',
        lastname: 'Doe',
        phone: '1234567890'
      )
    end

    let(:user_bill_address) do
      create(
        :address,
        city: 'New York',
        address1: '100 Main Street',
        address2: 'Apt 2',
        postal_code: '10001',
        state: new_york_state,
        country: usa_country
      )
    end

    let(:usa_country) { Spree::Country.find_by(iso: 'US') || create(:usa_country) }
    let(:california_state) { create(:state, name: 'California', abbr: 'CA', country: usa_country) }
    let(:new_york_state) { create(:state, name: 'New York', abbr: 'NY', country: usa_country) }

    let(:gateway_customer) { Spree::GatewayCustomer.stripe.last }
    let(:stripe_customer) { Stripe::Customer.retrieve(gateway_customer.profile_id, { api_key: gateway.preferred_secret_key }) }

    it 'creates a new Stripe customer and gateway customer record' do
      VCR.use_cassette('create_customer') do
        expect { subject }.to change(Spree::GatewayCustomer, :count).by(1)

        expect(subject).to eq(gateway_customer)
        expect(subject.user).to eq(user)
        expect(subject.profile_id).to eq(gateway_customer.profile_id)
        expect(subject.payment_method).to eq(gateway)
        expect(subject.persisted?).to be(true)

        expect(stripe_customer.email).to eq(order.email)
        expect(stripe_customer.name).to eq(order.name)

        expect(stripe_customer.address.city).to eq(bill_address.city)
        expect(stripe_customer.address.line1).to eq(bill_address.address1)
        expect(stripe_customer.address.line2).to eq(bill_address.address2)
        expect(stripe_customer.address.postal_code).to eq(bill_address.zipcode)
        expect(stripe_customer.address.state).to eq(california_state.name)
        expect(stripe_customer.address.country).to eq(usa_country.name)
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'creates a customer but does not save the gateway customer record' do
        VCR.use_cassette('create_customer') do
          expect { subject }.not_to change(Spree::GatewayCustomer, :count)

          expect(subject).to be_new_record
          expect(subject.user).to be_nil
          expect(subject.profile_id).to be_present
          expect(subject.payment_method).to eq(gateway)
        end
      end
    end

    context 'when only user is provided' do
      subject { gateway.create_customer(user: user) }

      it 'creates a customer using only user information' do
        VCR.use_cassette('create_customer_based_on_user') do
          expect { subject }.to change(Spree::GatewayCustomer, :count).by(1)

          expect(subject).to eq(gateway_customer)
          expect(subject.user).to eq(user)
          expect(subject.profile_id).to eq(gateway_customer.profile_id)
          expect(subject.payment_method).to eq(gateway)
          expect(subject.persisted?).to be(true)

          expect(stripe_customer.email).to eq(user.email)
          expect(stripe_customer.name).to eq(user.name)

          expect(stripe_customer.address.city).to eq(user_bill_address.city)
          expect(stripe_customer.address.line1).to eq(user_bill_address.address1)
          expect(stripe_customer.address.line2).to eq(user_bill_address.address2)
          expect(stripe_customer.address.postal_code).to eq(user_bill_address.zipcode)
          expect(stripe_customer.address.state).to eq(new_york_state.name)
          expect(stripe_customer.address.country).to eq(usa_country.name)
        end
      end
    end
  end

  describe '#update_customer' do
    subject { gateway.update_customer(order: order, user: user) }

    let(:order) { create(:order_with_line_items, user: user, bill_address: bill_address) }
    let(:user) { create(:user, email: 'test-updated@example.com', first_name: 'Jane', last_name: 'Moe', bill_address: user_bill_address) }

    let(:bill_address) do
      create(
        :address,
        city: 'San Francisco',
        address1: '200 California Street',
        address2: 'Apt 11',
        postal_code: '94112',
        state: california_state,
        country: usa_country,
        firstname: 'John',
        lastname: 'Doe'
      )
    end

    let(:user_bill_address) do
      create(
        :address,
        city: 'New York',
        address1: '200 Main Street',
        address2: 'Apt 22',
        postal_code: '10002',
        state: new_york_state,
        country: usa_country
      )
    end

    let(:usa_country) { Spree::Country.find_by(iso: 'US') || create(:usa_country) }
    let(:california_state) { create(:state, name: 'California', abbr: 'CA', country: usa_country) }
    let(:new_york_state) { create(:state, name: 'New York', abbr: 'NY', country: usa_country) }

    let!(:gateway_customer) { create(:gateway_customer, user: user, profile_id: customer_id, payment_method: gateway) }
    let(:customer_id) { 'cus_SeIsxI1TG3dGJv' }

    let(:stripe_customer) { Stripe::Customer.retrieve(customer_id, { api_key: gateway.preferred_secret_key }) }

    it 'updates the existing Stripe customer' do
      VCR.use_cassette('update_customer') do
        expect { subject }.not_to change(Spree::GatewayCustomer, :count)

        expect(subject).to eq(stripe_customer)

        expect(stripe_customer.email).to eq(order.email)
        expect(stripe_customer.name).to eq(order.name)

        expect(stripe_customer.address.city).to eq(bill_address.city)
        expect(stripe_customer.address.line1).to eq(bill_address.address1)
        expect(stripe_customer.address.line2).to eq(bill_address.address2)
        expect(stripe_customer.address.postal_code).to eq(bill_address.zipcode)
        expect(stripe_customer.address.state).to eq(california_state.name)
        expect(stripe_customer.address.country).to eq(usa_country.name)
      end
    end

    context 'when user is nil' do
      let(:user) { nil }
      let(:gateway_customer) { nil }

      it 'does nothing' do
        expect(subject).to be_nil
      end
    end

    context 'when gateway customer does not exist' do
      let(:gateway_customer) { nil }

      it 'does nothing' do
        expect(subject).to be_nil
      end
    end

    context 'when only user is provided' do
      subject { gateway.update_customer(user: user) }

      it 'updates the customer using only user information' do
        VCR.use_cassette('update_customer_based_on_user') do
          expect { subject }.not_to change(Spree::GatewayCustomer, :count)

          expect(subject).to eq(stripe_customer)

          expect(stripe_customer.email).to eq(user.email)
          expect(stripe_customer.name).to eq(user.name)

          expect(stripe_customer.address.city).to eq(user_bill_address.city)
          expect(stripe_customer.address.line1).to eq(user_bill_address.address1)
          expect(stripe_customer.address.line2).to eq(user_bill_address.address2)
          expect(stripe_customer.address.postal_code).to eq(user_bill_address.zipcode)
          expect(stripe_customer.address.state).to eq(new_york_state.name)
          expect(stripe_customer.address.country).to eq(usa_country.name)
        end
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

  describe '#create_tax_calculation' do
    subject { gateway.create_tax_calculation(order) }

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

    it 'creates a tax calculation' do
      VCR.use_cassette('create_tax_calculation_us_tx') do
        subject

        expect(subject.object).to eq('tax.calculation')
        expect(subject.currency).to eq('usd')

        customer_address = subject.customer_details.address
        expect(customer_address.city).to eq('Lancaster')
        expect(customer_address.country).to eq('US')
        expect(customer_address.line1).to eq('3201 North Dallas Avenue')
        expect(customer_address.postal_code).to eq('75134')
        expect(customer_address.state).to eq('TX')

        tax_breakdown = subject.tax_breakdown.first
        expect(tax_breakdown.taxable_amount).to eq(7000) # line items total is 6000, shipping is 1000
        expect(tax_breakdown.amount).to eq(560)
        expect(tax_breakdown.tax_rate_details.tax_type).to eq('sales_tax')
        expect(tax_breakdown.tax_rate_details.percentage_decimal).to eq('8.0')
        expect(tax_breakdown.tax_rate_details.state).to eq('TX')
        expect(tax_breakdown.tax_rate_details.country).to eq('US')

        tax_line_item_1 = subject.line_items.data[0]
        expect(tax_line_item_1.amount).to eq(1000)
        expect(tax_line_item_1.amount_tax).to eq(80)
        expect(tax_line_item_1.tax_code).to eq('txcd_10000000')

        tax_line_item_2 = subject.line_items.data[1]
        expect(tax_line_item_2.amount).to eq(2000)
        expect(tax_line_item_2.amount_tax).to eq(160)
        expect(tax_line_item_2.tax_code).to eq('txcd_10000000')

        tax_line_item_3 = subject.line_items.data[2]
        expect(tax_line_item_3.amount).to eq(3000)
        expect(tax_line_item_3.amount_tax).to eq(240)
        expect(tax_line_item_3.tax_code).to eq('txcd_10000000')

        shipping_cost = subject.shipping_cost
        expect(shipping_cost.amount).to eq(1000)
        expect(shipping_cost.amount_tax).to eq(80)
        expect(shipping_cost.tax_code).to eq('txcd_92010001')
      end
    end
  end

  describe '#create_tax_transaction' do
    subject { gateway.create_tax_transaction(payment_intent_id, tax_calculation_id) }

    let(:payment_intent_id) { 'pi_1234567890' }
    let(:tax_calculation_id) { 'taxcalc_1S52FRFmGsiQWfE6hVIABQtT' }

    it 'creates a tax transaction' do
      VCR.use_cassette('create_tax_transaction_us_tx') do
        subject

        expect(subject.object).to eq('tax.transaction')

        customer_address = subject.customer_details.address
        expect(customer_address.city).to eq('Lancaster')
        expect(customer_address.country).to eq('US')
        expect(customer_address.line1).to eq('3201 North Dallas Avenue')
        expect(customer_address.postal_code).to eq('75134')
        expect(customer_address.state).to eq('TX')

        line_items = subject.line_items.data
        expect(line_items.map(&:amount)).to eq([1000, 2000, 3000])
        expect(line_items.map(&:amount_tax)).to eq([80, 160, 240])
        expect(line_items.map(&:tax_code)).to eq(['txcd_10000000', 'txcd_10000000', 'txcd_10000000'])

        shipping_cost = subject.shipping_cost
        expect(shipping_cost.amount).to eq(1000)
        expect(shipping_cost.amount_tax).to eq(80)
        expect(shipping_cost.tax_code).to eq('txcd_92010001')
      end
    end
  end

  describe '#attach_customer_to_credit_card' do
    subject(:attach_customer) { gateway.attach_customer_to_credit_card(user) }

    context 'when no payment method is provided' do
      context 'and user is nil' do
        let(:user) { nil }

        it 'does not create a new gateway customer' do
          expect { attach_customer }.not_to change(Spree::GatewayCustomer, :count)
        end
        
        it 'returns nil' do
          expect(attach_customer).to be_nil
        end
      end

      context 'and user has no default credit card' do
        let(:user) { create(:user) }

        it 'does not create a new gateway customer' do
          expect { attach_customer }.not_to change(Spree::GatewayCustomer, :count)
        end
        
        it 'returns nil' do
          expect(attach_customer).to be_nil
        end
      end

      context 'and credit card has no payment method id' do
        let(:user) { create(:user) }
        let!(:credit_card) { create(:credit_card, user: user, default: true) }

        it 'does not create a new gateway customer' do
          expect { attach_customer }.not_to change(Spree::GatewayCustomer, :count)
        end
        
        it 'returns nil' do
          expect(attach_customer).to be_nil
        end
      end
    end

    context 'when credit card has a payment method id' do
      let(:user) { create(:user) }

      context 'and credit card has no gateway customer profile id' do
        let!(:credit_card) { create(:credit_card, user: user, default: true, gateway_payment_profile_id: 'pm_1SGLXEIhR0gIegIeYbkKLGkF') }

        it 'attaches the customer to the credit card' do        
          VCR.use_cassette('attach_customer_to_credit_card') do
            expect { attach_customer }.to change(Spree::GatewayCustomer, :count).by(1)
            expect(user.reload.default_credit_card.gateway_customer_profile_id).to eq('cus_TFeSJ7nmvElKTT')
            expect(user.reload.default_credit_card.gateway_customer_id).to eq(Spree::GatewayCustomer.last.id)
          end
        end
      end

      context 'and credit card has a gateway customer profile id' do
        let!(:credit_card) { create(:credit_card, user: user, default: true, gateway_payment_profile_id: 'pm_1SGLXEIhR0gIegIeYbkKLGkF', gateway_customer_profile_id: 'cus_TFeSJ7nmvElKTT') }

        it 'does not create a new gateway customer' do
          expect { attach_customer }.not_to change(Spree::GatewayCustomer, :count)
        end

        it 'returns nil' do
          expect(attach_customer).to be_nil
        end
      end
    end
  end
end
