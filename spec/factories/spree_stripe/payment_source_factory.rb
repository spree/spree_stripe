FactoryBot.define do
  factory :payment_source, class: Spree::PaymentSource do
    association :payment_method, factory: :payment_method
    gateway_payment_profile_id { 'pm_1adfg34fgfdf5245' }
    type { 'SpreeStripe::PaymentSources::Alipay' }
    user
  end
end
