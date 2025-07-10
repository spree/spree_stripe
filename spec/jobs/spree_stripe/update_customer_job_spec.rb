require 'spec_helper'

RSpec.describe SpreeStripe::UpdateCustomerJob do
  subject { described_class.new.perform(user.id) }

  let(:user) { create(:user) }

  it 'calls SpreeStripe::UpdateCustomer service' do
    expect(SpreeStripe::UpdateCustomer).to receive_message_chain(:new, :call).with(user: user)
    subject
  end

  context 'when user is not found' do
    let(:user) { double(:user, id: 999999) }

    it 'raises ActiveRecord::RecordNotFound' do
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
