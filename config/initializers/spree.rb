Rails.application.config.after_initialize do
  Rails.application.config.spree.payment_methods << SpreeStripe::Gateway

  if Rails.application.config.respond_to?(:spree_storefront)
    Rails.application.config.spree_storefront.head_partials << 'spree_stripe/head'
    Rails.application.config.spree_storefront.quick_checkout_partials << 'spree_stripe/quick_checkout'
  end
end
