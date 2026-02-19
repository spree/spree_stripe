Spree::Core::Engine.add_routes do
  # Stripe payment intents
  get '/stripe/payment_intents/:id', to: '/spree_stripe/payment_intents#show',
                                     as: :stripe_payment_intent,
                                     controller: '/spree_stripe/payment_intents'

  # Apple Pay domain verification certificate for Apple Pay
  get '/.well-known/apple-developer-merchantid-domain-association' => '/spree_stripe/apple_pay_domain_verification#show'

  # Stripe webhooks
  mount StripeEvent::Engine, at: '/stripe'

  # Storefront API (only when spree_legacy_api_v2 gem is available)
  if defined?(SpreeLegacyApiV2::Engine)
    namespace :api, defaults: { format: 'json' } do
      namespace :v2 do
        namespace :storefront do
          namespace :stripe do
            resources :setup_intents, only: %i[create]
            resources :payment_intents, only: %i[show create update] do
              member do
                patch :confirm
              end
            end
          end
        end
      end
    end
  end
end
