module SpreeStripe
  module OrderDecorator
    def self.prepended(base)
      base.has_many :payment_intents, class_name: 'SpreeStripe::PaymentIntent', dependent: :destroy
    end

    def update_payment_intents
      return if completed?
      return unless total_minus_store_credits.positive?

      payment_intents.each do |payment_intent|
        payment_intent.update!(amount: total_minus_store_credits)
      end
    end

    def associate_user!(user, override_email = true)
      super(user, override_email)

      return if payment_intents.empty?

      responses = payment_intents.map { |payment_intent| payment_intent.update_stripe_payment_intent }
      customer_id = responses.find { |response| response.params['customer'].present? }&.params['customer']

      payment_intents.update_all(customer_id: customer_id) if customer_id.present?
    end
  end
end

Spree::Order.prepend(SpreeStripe::OrderDecorator)
Spree::Order.register_update_hook :update_payment_intents
