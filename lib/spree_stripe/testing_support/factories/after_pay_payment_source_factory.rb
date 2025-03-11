FactoryBot.define do
  factory :after_pay_payment_source, class: SpreeStripe::PaymentSources::AfterPay do
    payment_method { create(:stripe_gateway) }
    type { 'SpreeStripe::PaymentSources::AfterPay' }
  end
end
