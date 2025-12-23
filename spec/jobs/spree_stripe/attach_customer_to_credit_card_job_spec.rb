require 'spec_helper'

RSpec.describe SpreeStripe::AttachCustomerToCreditCardJob do
  subject { described_class.new.perform(gateway.id, user.id) }

  let(:store) { Spree::Store.default }
  let(:user) { create(:user) }
  let(:gateway) { create(:stripe_gateway, stores: [store]) }

  it 'calls attach_customer_to_credit_card on the gateway' do
    expect_any_instance_of(SpreeStripe::Gateway).to receive(:attach_customer_to_credit_card).with(user)
    subject
  end

  context 'when gateway is not found' do
    subject { described_class.new.perform(nil, user.id) }

    it 'returns early without raising' do
      expect_any_instance_of(SpreeStripe::Gateway).not_to receive(:attach_customer_to_credit_card)
      expect { subject }.not_to raise_error
    end
  end

  context 'when user is not found' do
    subject { described_class.new.perform(gateway.id, nil) }

    it 'returns early without raising' do
      expect_any_instance_of(SpreeStripe::Gateway).not_to receive(:attach_customer_to_credit_card)
      expect { subject }.not_to raise_error
    end
  end
end

