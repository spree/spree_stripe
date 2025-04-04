require 'spec_helper'

RSpec.describe Spree::V2::Storefront::PaymentIntentSerializer do
  subject { described_class.new(payment_intent).serializable_hash }

  include_context 'API v2 serializers params'

  let(:payment) { create(:payment) }
  let(:payment_intent) { create(:payment_intent, payment: payment, payment_method: payment.payment_method) }

  it 'serializes the payment intent' do
    expect(subject).to eq(
      {
        data: {
          type: :payment_intent,
          attributes: {
            stripe_id: payment_intent.stripe_id,
            client_secret: payment_intent.client_secret,
            ephemeral_key_secret: payment_intent.ephemeral_key_secret,
            customer_id: payment_intent.customer_id,
            amount: payment_intent.amount,
            stripe_payment_method_id: payment_intent.stripe_payment_method_id
          },
          id: payment_intent.id.to_s,
          relationships: {
            order: {
              data: {
                id: payment_intent.order.id.to_s,
                type: :order
              }
            },
            payment_method: {
              data: {
                id: payment_intent.payment_method.id.to_s,
                type: :payment_method
              }
            },
            payment: {
              data: {
                id: payment_intent.payment.id.to_s,
                type: :payment
              }
            }
          }
        }
      }
    )
  end
end
