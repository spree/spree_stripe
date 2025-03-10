FactoryBot.define do
  factory :link_payment_source, class: SpreeStripe::PaymentSources::Link do
    payment_method { create(:stripe_gateway) }
    type { 'SpreeStripe::PaymentSources::Link' }
  end
end
