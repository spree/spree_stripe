require 'spec_helper'

RSpec.describe SpreeStripe::CustomDomainDecorator do
  let(:store) { Spree::Store.default }

  describe '#register_stripe_domain' do
    subject(:create_custom_domain) { create(:custom_domain, store: store) }

    context 'with a Stripe gateway' do
      before { create(:stripe_gateway, stores: [store]) }

      it 'registers the Apple Pay domain' do
        expect { create_custom_domain }.to have_enqueued_job(SpreeStripe::RegisterDomainJob)
      end
    end

    context 'without a Stripe gateway' do
      before { create(:stripe_gateway, stores: [create(:store)]) }

      it 'does not register the Apple Pay domain' do
        expect { create_custom_domain }.not_to have_enqueued_job(SpreeStripe::RegisterDomainJob)
      end
    end
  end
end
