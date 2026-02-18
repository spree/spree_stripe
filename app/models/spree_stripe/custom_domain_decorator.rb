module SpreeStripe
  module CustomDomainDecorator
    def self.prepended(base)
      base.after_create :register_stripe_domain

      base.store_accessor :private_metadata, :stripe_apple_pay_domain_id
      base.store_accessor :private_metadata, :stripe_top_level_domain_id
    end

    def register_stripe_domain
      return if store.stripe_gateway.blank?

      SpreeStripe::RegisterDomainJob.perform_later(id, 'custom_domain')
    end
  end
end

if defined?(Spree::CustomDomain)
  Spree::CustomDomain.prepend(SpreeStripe::CustomDomainDecorator)
end
