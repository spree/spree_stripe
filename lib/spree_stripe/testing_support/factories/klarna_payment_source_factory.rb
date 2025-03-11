FactoryBot.define do
  factory :klarna_payment_source, class: SpreeStripe::PaymentSources::Klarna do
    payment_method { create(:stripe_gateway) }
    type { 'SpreeStripe::PaymentSources::Klarna' }
  end
end
