FactoryBot.define do
  factory :stripe_gateway, parent: :payment_method, class: SpreeStripe::Gateway do
    name { 'Stripe' }
    type { 'SpreeStripe::Gateway' }

    preferences do
      {
        publishable_key: ENV.fetch('STRIPE_PUBLISHABLE_KEY', 'pk_test_1234567890'),
        secret_key: ENV.fetch('STRIPE_SECRET_KEY', 'sk_test_1234567890')
      }
    end

    trait :with_apple_domain_association_file do
      transient do
        apple_domain_association_file_path do
          File.join(SpreeStripe::Engine.root, 'spec', 'fixtures', 'files', 'apple-domain-association-file.txt')
        end
      end

      apple_developer_merchantid_domain_association { Rack::Test::UploadedFile.new(apple_domain_association_file_path) }
    end
  end
end
