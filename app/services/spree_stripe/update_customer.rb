module SpreeStripe
  class UpdateCustomer
    def call(user:)
      gateway_customers = user.gateway_customers.stripe
      return if gateway_customers.empty?

      gateway_customers.each do |gateway_customer|
        stripe_gateway = gateway_customer.payment_method
        stripe_gateway.update_customer(user: user)
      end
    end
  end
end
