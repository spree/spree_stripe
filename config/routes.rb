Spree::Core::Engine.add_routes do
  # Stripe redirects here after payment confirmation. It completes the session + order server-side.
  # Used by Rails storefront
  get '/stripe/confirm_payment/:id', to: '/spree_stripe/confirm_payments#show', as: :stripe_confirm_payment

  # Apple Pay domain verification certificate for Apple Pay
  get '/.well-known/apple-developer-merchantid-domain-association' => '/spree_stripe/apple_pay_domain_verification#show'

  # Stripe webhooks
  mount StripeEvent::Engine, at: '/stripe'
end
