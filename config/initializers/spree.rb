Rails.application.config.after_initialize do
  Rails.application.config.spree.payment_methods << SpreeStripe::Gateway
  Rails.application.config.spree.calculators.tax_rates << SpreeStripe::Calculators::StripeTax

  if Rails.application.config.respond_to?(:spree_storefront)
    Rails.application.config.spree_storefront.head_partials << 'spree_stripe/head'

    # Quick checkout partial depends on the legacy Storefront API v2
    if defined?(SpreeLegacyApiV2::Engine)
      Rails.application.config.spree_storefront.quick_checkout_partials << 'spree_stripe/quick_checkout'
    end
  end
end
