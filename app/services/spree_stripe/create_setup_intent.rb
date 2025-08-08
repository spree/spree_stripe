module SpreeStripe
  class CreateSetupIntent
    prepend Spree::ServiceModule::Base

    def call(gateway:, user:, payment_methods: [])
      customer = gateway.fetch_or_create_customer(user: user)

      ephemeral_key_response = gateway.create_ephemeral_key(customer.profile_id)
      setup_intent = gateway.create_setup_intent(customer.profile_id, payment_methods)

      success(
        {
          customer_id: customer.profile_id,
          ephemeral_key_secret: ephemeral_key_response.params['secret'],
          setup_intent_client_secret: setup_intent.params['client_secret']
        }
      )
    end
  end
end
