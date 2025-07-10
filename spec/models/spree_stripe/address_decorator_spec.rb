require 'spec_helper'

RSpec.describe SpreeStripe::AddressDecorator do
  let(:user) { create(:user) }
  let(:address) { create(:address, user: user) }

  describe '#update_stripe_customer' do
    it 'delegates to user' do
      expect(user).to receive(:update_stripe_customer)
      address.update_stripe_customer
    end

    context 'when address has no user' do
      let(:address) { create(:address, user: nil) }

      it 'does not raise an error' do
        expect { address.update_stripe_customer }.not_to raise_error
      end
    end
  end

  describe 'after_update :update_stripe_customer' do
    subject { address.update!(params) }

    context 'when address is user default billing address' do
      before { user.update!(bill_address: address) }

      context 'when address attributes change' do
        let(:params) { { city: 'New City' } }

        it 'updates the Stripe customer in the background' do
          expect { subject }.to have_enqueued_job(SpreeStripe::UpdateCustomerJob).with(user.id)
        end
      end

      context 'when address line1 changes' do
        let(:params) { { address1: '123 New Street' } }

        it 'updates the Stripe customer in the background' do
          expect { subject }.to have_enqueued_job(SpreeStripe::UpdateCustomerJob).with(user.id)
        end
      end

      context 'when address line2 changes' do
        let(:params) { { address2: 'Apt 456' } }

        it 'updates the Stripe customer in the background' do
          expect { subject }.to have_enqueued_job(SpreeStripe::UpdateCustomerJob).with(user.id)
        end
      end

      context 'when zipcode changes' do
        let(:params) { { zipcode: '12345' } }

        it 'updates the Stripe customer in the background' do
          expect { subject }.to have_enqueued_job(SpreeStripe::UpdateCustomerJob).with(user.id)
        end
      end

      context 'when no attributes change' do
        let(:params) { {} }

        it 'does not update the Stripe customer in the background' do
          expect { subject }.not_to have_enqueued_job(SpreeStripe::UpdateCustomerJob)
        end
      end
    end

    context 'when address is user default shipping address but not billing' do
      before { user.update!(ship_address: address, bill_address: create(:address)) }

      context 'when address attributes change' do
        let(:params) { { city: 'New City' } }

        it 'does not update the Stripe customer in the background' do
          expect { subject }.not_to have_enqueued_job(SpreeStripe::UpdateCustomerJob)
        end
      end
    end

    context 'when address is not associated with a user' do
      let(:address) { create(:address, user: nil) }

      context 'when address attributes change' do
        let(:params) { { city: 'New City' } }

        it 'does not update the Stripe customer in the background' do
          expect { subject }.not_to have_enqueued_job(SpreeStripe::UpdateCustomerJob)
        end
      end
    end

    context 'when address is not a user default address' do
      let(:other_address) { create(:address) }
      before { user.update!(bill_address: other_address, ship_address: other_address) }

      context 'when address attributes change' do
        let(:params) { { city: 'New City' } }

        it 'does not update the Stripe customer in the background' do
          expect { subject }.not_to have_enqueued_job(SpreeStripe::UpdateCustomerJob)
        end
      end
    end
  end
end
