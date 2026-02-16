FactoryBot.define do
  factory :stripe_payment_session, class: 'Spree::PaymentSessions::Stripe' do
    order { create(:order_with_line_items) }
    payment_method { create(:stripe_gateway, stores: [order.store]) }
    amount { order.total }
    currency { order.currency }
    status { 'pending' }
    type { 'Spree::PaymentSessions::Stripe' }
    external_id { "pi_test_#{SecureRandom.hex(12)}" }
    external_data { { 'client_secret' => "pi_secret_#{SecureRandom.hex(8)}" } }

    trait :with_customer do
      customer { order.user || create(:user) }
      customer_external_id { "cus_#{SecureRandom.hex(8)}" }
    end

    trait :with_ephemeral_key do
      external_data { { 'client_secret' => "pi_secret_#{SecureRandom.hex(8)}", 'ephemeral_key_secret' => "ek_test_#{SecureRandom.hex(8)}" } }
    end

    trait :processing do
      status { 'processing' }
    end

    trait :completed do
      status { 'completed' }
    end

    trait :failed do
      status { 'failed' }
    end
  end
end
