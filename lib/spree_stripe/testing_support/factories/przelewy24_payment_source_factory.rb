FactoryBot.define do
  factory :przelewy24_payment_source, class: SpreeStripe::PaymentSources::Przelewy24 do
    payment_method { create(:stripe_gateway) }
    type { 'SpreeStripe::PaymentSources::Przelewy24' }
  end
end
