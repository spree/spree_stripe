module SpreeStripe
  module StoreDecorator
    def self.prepended(base)
      base.store_accessor :private_metadata, :stripe_apple_pay_domain_id
      base.store_accessor :private_metadata, :stripe_top_level_domain_id
    end

    def stripe_gateway
      @stripe_gateway ||= payment_methods.stripe.active.last
    end

    def handle_code_changes
      super

      SpreeStripe::RegisterDomainJob.perform_later(id)
    end

    def billing_name
      name
    end
  end
end

Spree::Store.prepend(SpreeStripe::StoreDecorator)
