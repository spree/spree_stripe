module SpreeStripe
  class PaymentIntent < Base
    #
    # Associations
    #
    belongs_to :order, class_name: 'Spree::Order', foreign_key: 'order_id'
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod', foreign_key: 'payment_method_id'
    has_one :payment, class_name: 'Spree::Payment', foreign_key: 'response_code', primary_key: 'stripe_id'

    #
    # Validations
    #
    validates :order, :payment_method, :client_secret, presence: true
    validates :stripe_id, presence: true, uniqueness: { scope: :order_id }
    validates :amount, presence: true, numericality: { greater_than: 0 }

    #
    # Callbacks
    #
    before_validation :set_amount_from_order
    after_update :update_stripe_payment_intent, if: :amount_or_stripe_payment_method_id_changed?

    #
    # Delegations
    #
    delegate :api_options, to: :payment_method
    delegate :store, :currency, to: :order

    def accepted?
      payment_method.payment_intent_accepted?(stripe_payment_intent)
    end

    def successful?
      stripe_payment_intent.status == 'succeeded'
    end

    def stripe_payment_intent
      @stripe_payment_intent ||= payment_method.retrieve_payment_intent(stripe_id)
    end

    def stripe_charge
      @stripe_charge ||= payment_method.retrieve_charge(stripe_payment_intent.latest_charge)
    end

    # here we create a payment if it doesn't exist
    # or we find it by the stripe_payment_intent_id
    def find_or_create_payment!
      return unless persisted?
      return payment if payment.present?

      SpreeStripe::CreatePayment.new(order: order, payment_intent: self, gateway: payment_method, amount: amount).call
    end

    def set_amount_from_order
      self.amount = order&.total_minus_store_credits if order.present? && (amount.nil? || amount.zero?)
    end

    def update_stripe_payment_intent
      payment_method.update_payment_intent(stripe_id, amount_in_cents, order, stripe_payment_method_id)
    end

    def amount_or_stripe_payment_method_id_changed?
      amount_previously_changed? || stripe_payment_method_id_previously_changed?
    end

    def amount_in_cents
      @amount_in_cents ||= money.cents
    end

    def money
      @money ||= Spree::Money.new(amount, currency: currency)
    end
  end
end
