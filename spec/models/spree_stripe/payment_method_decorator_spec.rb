require 'spec_helper'

RSpec.describe SpreeStripe::PaymentMethodDecorator do
  describe '#stripe?' do
    subject { payment_method.stripe? }

    context 'for a Stripe gateway' do
      let(:payment_method) { create(:stripe_gateway) }

      it { is_expected.to be(true) }
    end

    context 'for a non-Stripe gateway' do
      let(:payment_method) { create(:check_payment_method) }

      it { is_expected.to be(false) }
    end
  end
end
