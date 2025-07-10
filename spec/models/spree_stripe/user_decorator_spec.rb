require 'spec_helper'

RSpec.describe SpreeStripe::UserDecorator do
  let(:user) { create(:user) }

  describe '#update_stripe_customer' do
    it 'enqueues UpdateCustomerJob' do
      expect { user.update_stripe_customer }.to have_enqueued_job(SpreeStripe::UpdateCustomerJob).with(user.id)
    end
  end

  describe 'after_update :update_stripe_customer' do
    subject { user.update!(params) }

    context 'when ship address changes' do
      let(:params) { { ship_address: create(:address) } }

      it 'updates the Stripe customer in the background' do
        expect { subject }.to have_enqueued_job(SpreeStripe::UpdateCustomerJob).with(user.id)
      end
    end

    context 'when bill address changes' do
      let(:params) { { bill_address: create(:address) } }

      it 'updates the Stripe customer in the background' do
        expect { subject }.to have_enqueued_job(SpreeStripe::UpdateCustomerJob).with(user.id)
      end
    end

    context 'when first name changes' do
      let(:params) { { first_name: 'New First Name' } }

      it 'updates the Stripe customer in the background' do
        expect { subject }.to have_enqueued_job(SpreeStripe::UpdateCustomerJob).with(user.id)
      end
    end

    context 'when last name changes' do
      let(:params) { { last_name: 'New Last Name' } }

      it 'updates the Stripe customer in the background' do
        expect { subject }.to have_enqueued_job(SpreeStripe::UpdateCustomerJob).with(user.id)
      end
    end

    context 'when email changes' do
      let(:params) { { email: 'new@example.com' } }

      it 'updates the Stripe customer in the background' do
        expect { subject }.to have_enqueued_job(SpreeStripe::UpdateCustomerJob).with(user.id)
      end
    end

    context 'when irrelevant attributes change' do
      let(:params) { { phone: '123-456-7890' } }

      it 'does not update the Stripe customer in the background' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::UpdateCustomerJob)
      end
    end

    context 'when no attributes change' do
      let(:params) { {} }

      it 'does not update the Stripe customer in the background' do
        expect { subject }.not_to have_enqueued_job(SpreeStripe::UpdateCustomerJob)
      end
    end
  end
end
