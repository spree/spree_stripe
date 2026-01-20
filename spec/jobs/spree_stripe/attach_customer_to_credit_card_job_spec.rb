require 'spec_helper'

RSpec.describe SpreeStripe::AttachCustomerToCreditCardJob do
  include ActiveJob::TestHelper

  let(:store) { Spree::Store.default }
  let(:user) { create(:user) }
  let!(:gateway) { create(:stripe_gateway, stores: [store]) }
  let(:order) { create(:completed_order_with_totals, store: store, user: user) }

  subject { described_class.new.perform(order.id) }

  it 'calls attach_customer_to_credit_card on the gateway' do
    expect_any_instance_of(SpreeStripe::Gateway).to receive(:attach_customer_to_credit_card).with(user)
    subject
  end

  context 'when order is not found' do
    subject { described_class.new.perform(0) }

    it 'returns early without raising' do
      expect_any_instance_of(SpreeStripe::Gateway).not_to receive(:attach_customer_to_credit_card)
      expect { subject }.not_to raise_error
    end
  end

  context 'when order has no user' do
    let(:order) { create(:completed_order_with_totals, store: store, user: nil) }

    it 'returns early without raising' do
      expect_any_instance_of(SpreeStripe::Gateway).not_to receive(:attach_customer_to_credit_card)
      expect { subject }.not_to raise_error
    end
  end

  context 'when store has no stripe gateway' do
    before { gateway.destroy }

    it 'returns early without raising' do
      expect_any_instance_of(SpreeStripe::Gateway).not_to receive(:attach_customer_to_credit_card)
      expect { subject }.not_to raise_error
    end
  end

  context 'when user class is not configured' do
    before { allow(Spree).to receive(:user_class).and_return(nil) }

    it 'returns early without raising' do
      expect_any_instance_of(SpreeStripe::Gateway).not_to receive(:attach_customer_to_credit_card)
      expect { subject }.not_to raise_error
    end
  end
end
