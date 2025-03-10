FactoryBot.define do
  factory :ideal_payment_source, class: SpreeStripe::PaymentSources::Ideal do
    payment_method { create(:stripe_gateway) }
    type { 'SpreeStripe::PaymentSources::Ideal' }
  end
end
