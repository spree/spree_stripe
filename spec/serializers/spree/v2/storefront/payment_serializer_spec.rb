require 'spec_helper'

RSpec.describe Spree::V2::Storefront::PaymentSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(payment).serializable_hash }

  let(:payment) { build(:payment, payment_method: create(:stripe_gateway), source: source) }

  describe 'payment source' do
    context 'for klarna' do
      let(:source) { create(:klarna_payment_source) }

      it { expect(subject[:data][:relationships][:source][:data][:type]).to eq :klarna }
    end

    context 'for AfterPay' do
      let(:source) { create(:after_pay_payment_source) }

      it { expect(subject[:data][:relationships][:source][:data][:type]).to eq :after_pay }
    end

    context 'for Alipay' do
      let(:source) { create(:alipay_payment_source) }

      it { expect(subject[:data][:relationships][:source][:data][:type]).to eq :alipay }
    end

    context 'for Ideal' do
      let(:source) { create(:ideal_payment_source) }

      it { expect(subject[:data][:relationships][:source][:data][:type]).to eq :ideal }
    end

    context 'for Link' do
      let(:source) { create(:link_payment_source) }

      it { expect(subject[:data][:relationships][:source][:data][:type]).to eq :link }
    end

    context 'for Przelewy24' do
      let(:source) { create(:przelewy24_payment_source) }

      it { expect(subject[:data][:relationships][:source][:data][:type]).to eq :przelewy24 }
    end

    context 'for SepaDebit' do
      let(:source) { create(:sepa_debit_payment_source) }

      it { expect(subject[:data][:relationships][:source][:data][:type]).to eq :sepa_debit }
    end

    context 'for Store Credits' do
      let(:source) { create(:store_credit) }
      let(:payment) { build(:payment, payment_method: create(:store_credit_payment_method), source: source) }

      it { expect(subject[:data][:relationships][:source][:data][:type]).to eq :store_credit }
    end
  end
end
