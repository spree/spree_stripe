require 'spec_helper'

RSpec.describe SpreeStripe::RegisterDomain do
  subject(:register_domain) { described_class.new.call(model: model) }

  let(:store) { create(:store) }
  let!(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }

  let(:payment_method_domain) do
    Stripe::PaymentMethodDomain.list({ domain_name: domain }, stripe_gateway.api_options).data.find do |s_domain|
      s_domain.domain_name == domain
    end
  end
  let(:apple_pay_top_level_domain) do
    Stripe::PaymentMethodDomain.list({ domain_name: tld_domain }, stripe_gateway.api_options).data.find do |domain|
      domain.domain_name == tld_domain
    end
  end

  context 'for store' do
    let(:model) { store }
    let(:domain) { model.url }

    before do
      allow(model).to receive(:url).and_return('dare-gerhold-and-pagac.lvh.me')
    end

    it 'register only store domain', :vcr do
      expect(Stripe::PaymentMethodDomain).to receive(:create).once.with({ domain_name: domain }).and_call_original
      register_domain

      expect(payment_method_domain).to be_present
      expect(model.stripe_apple_pay_domain_id).to eq(payment_method_domain.id)
    end
  end

  context 'for custom domain' do
    let(:model) { create(:custom_domain, url: domain, store: store) }

    context 'when tld length is more then 2' do
      let(:tld_domain) { 'store-with-apple-pay.com' }
      let(:domain) { "shop.#{tld_domain}" }

      it 'registers the Apple Pay domain and top level domain in Stripe', :vcr do
        register_domain

        expect(payment_method_domain).to be_present
        expect(apple_pay_top_level_domain).to be_present
        expect(model.stripe_apple_pay_domain_id).to eq(payment_method_domain.id)
        expect(model.stripe_top_level_domain_id).to eq(apple_pay_top_level_domain.id)
      end
    end

    context 'when tld length is 2' do
      let(:tld_domain) { 'store-with-apple-pay.com' }
      let(:domain) { tld_domain }

      it 'registers only custom domain', :vcr do
        expect(Stripe::PaymentMethodDomain).to receive(:create).once.with({ domain_name: domain }).and_call_original
        register_domain

        expect(payment_method_domain).to be_present
        expect(model.stripe_apple_pay_domain_id).to eq(payment_method_domain.id)
        expect(model.stripe_top_level_domain_id).to be_nil
      end
    end
  end
end
