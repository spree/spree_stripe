# == Schema Information
#
# Table name: spree_stripe_webhook_keys
#
#  id             :bigint           not null, primary key
#  kind           :integer          default("direct")
#  signing_secret :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  stripe_id      :string           not null
#
FactoryBot.define do
  factory :stripe_webhook_key, class: SpreeStripe::WebhookKey do
    stripe_id { generate(:random_string) }
    signing_secret { generate(:random_string) }

    before(:create) do |wk|
      if wk.payment_methods.empty?
        wk.payment_methods << create(:stripe_gateway)
      end
    end
  end
end
