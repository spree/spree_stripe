require 'spec_helper'

RSpec.describe SpreeStripe::CompleteOrderFromSessionJob do
  subject { described_class.new.perform(payment_session.id) }

  let(:store) { Spree::Store.default }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
  let(:payment_session) do
    create(:stripe_payment_session,
           order: order,
           payment_method: stripe_gateway,
           external_id: 'pi_test_job_123')
  end

  it 'calls SpreeStripe::CompleteOrder with the payment session' do
    expect(SpreeStripe::CompleteOrder).to receive(:new).with(payment_intent: payment_session).and_return(double(call: order))
    subject
  end

  it 'completes the payment session' do
    allow(SpreeStripe::CompleteOrder).to receive_message_chain(:new, :call).and_return(order)
    subject
    expect(payment_session.reload.status).to eq('completed')
  end

  context 'when already completed' do
    before { payment_session.update_column(:status, 'completed') }

    it 'does not raise' do
      allow(SpreeStripe::CompleteOrder).to receive_message_chain(:new, :call).and_return(order)
      expect { subject }.not_to raise_error
    end
  end
end
