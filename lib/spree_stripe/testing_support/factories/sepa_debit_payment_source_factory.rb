FactoryBot.define do
  factory :sepa_debit_payment_source, class: SpreeStripe::PaymentSources::SepaDebit do
    payment_method { create(:stripe_gateway) }
    type { 'SpreeStripe::PaymentSources::SepaDebit' }
  end
end
