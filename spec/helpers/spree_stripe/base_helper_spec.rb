require 'spec_helper'

RSpec.describe SpreeStripe::BaseHelper do
  let(:store) { Spree::Store.default }

  before do
    allow(helper).to receive(:current_store).and_return(store)
  end

  describe '#current_stripe_gateway' do
    it 'fetches the Stripe gateway for the current store' do
      expect(store).to receive(:stripe_gateway)
      helper.current_stripe_gateway
    end
  end
end
