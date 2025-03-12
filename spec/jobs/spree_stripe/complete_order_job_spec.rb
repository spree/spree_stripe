require 'spec_helper'

RSpec.describe SpreeStripe::CompleteOrderJob do
  subject { described_class.new.perform(payment_intent.id) }

  let(:store) { Spree::Store.default }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:payment_intent) { create(:payment_intent, order: order) }

  it 'calls SpreeStripe::CompleteOrder' do
    expect(SpreeStripe::CompleteOrder).to receive_message_chain(:new, :call).and_return(order)
    subject
  end
end
