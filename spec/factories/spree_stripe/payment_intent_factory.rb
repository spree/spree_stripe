# == Schema Information
#
# Table name: spree_stripe_payment_intents
#
#  id                       :bigint           not null, primary key
#  amount                   :decimal(10, 2)   default(0.0), not null
#  client_secret            :string           not null
#  ephemeral_key_secret     :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  customer_id              :string
#  order_id                 :bigint           not null
#  payment_method_id        :bigint           not null
#  stripe_id                :string           not null
#  stripe_payment_method_id :string
#
FactoryBot.define do
  factory :payment_intent, class: SpreeStripe::PaymentIntent do
    stripe_id { 'pi_123' }
    client_secret { 'cs_123' }
    order { create(:order_with_line_items) }
    payment_method { create(:stripe_gateway, stores: [order.store]) }
  end
end
