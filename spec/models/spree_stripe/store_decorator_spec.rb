require 'spec_helper'

RSpec.describe SpreeStripe::StoreDecorator do
  describe '#after_commit :handle_code_changes' do
    subject { store.update!(code: new_code) }

    describe 'registering Apple Pay domain in Stripe' do
      let(:store) { create(:store, code: 'store-with-stripe-1') }

      before { create(:stripe_gateway, stores: [store]) }

      context 'when code changed' do
        let(:new_code) { 'store-with-stripe-2' }

        it 'enqueues a job for registering a domain in Stripe' do
          expect { subject }.to have_enqueued_job(SpreeStripe::RegisterDomainJob)
        end
      end

      context "when code didn't change" do
        let(:new_code) { store.code }

        it 'enqueues nothing' do
          expect { subject }.not_to have_enqueued_job(SpreeStripe::RegisterDomainJob)
        end
      end
    end
  end

  describe '#stripe_gateway' do
    subject { store.stripe_gateway }

    let(:store) { Spree::Store.default }

    before { create(:stripe_gateway, stores: [store], active: false) }

    context 'when there is an active Stripe gateway' do
      let!(:active_stripe_gateway) { create(:stripe_gateway, stores: [store]) }

      it { is_expected.to eq(active_stripe_gateway) }
    end

    context 'when there is no active Stripe gateway' do
      it { is_expected.to be_nil }
    end
  end
end
