module SpreeStripe
  class RegisterDomain
    def call(model:)
      gateway = model.is_a?(Spree::Store) ? model.stripe_gateway : model.store.stripe_gateway

      payment_method_domain = gateway.send_request { Stripe::PaymentMethodDomain.create({ domain_name: model.url }) }

      attributes_to_update = { stripe_apple_pay_domain_id: payment_method_domain.id }

      tld_length = model.url.split('.').length
      if tld_length > 2 && model.is_a?(Spree::CustomDomain)
        top_level_domain_name = model.url.split('.').last(tld_length - 1).join('.')
        top_level_domain = gateway.send_request { Stripe::PaymentMethodDomain.create({ domain_name: top_level_domain_name }) }
        attributes_to_update[:stripe_top_level_domain_id] = top_level_domain.id
      end

      model.update!(**attributes_to_update)

      payment_method_domain
    end
  end
end
