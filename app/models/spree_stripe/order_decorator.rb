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
  end
end

Spree::Order.prepend(SpreeStripe::OrderDecorator)
Spree::Order.register_update_hook :update_payment_intents
