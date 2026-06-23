Spree::Core::Engine.add_routes do
  # Apple Pay domain verification certificate for Apple Pay
  get '/.well-known/apple-developer-merchantid-domain-association' => '/spree_stripe/apple_pay_domain_verification#show'

  # Stripe webhooks
  mount StripeEvent::Engine, at: '/stripe'
end
