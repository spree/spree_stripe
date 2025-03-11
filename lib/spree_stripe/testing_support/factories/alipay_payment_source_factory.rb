FactoryBot.define do
  factory :alipay_payment_source, class: SpreeStripe::PaymentSources::Alipay do
    payment_method { create(:stripe_gateway) }
    type { 'SpreeStripe::PaymentSources::Alipay' }
  end
end
