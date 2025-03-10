FactoryBot.define do
  factory :stripe_customer, class: SpreeStripe::Customer do
    sequence(:profile_id) { |n| "cus_#{n}" }
    user { |p| p.association(:user) }
    payment_method { |p| p.association(:payment_method) }
  end
end
