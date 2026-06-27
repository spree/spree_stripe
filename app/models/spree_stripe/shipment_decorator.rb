module SpreeStripe
  module ShipmentDecorator
    def self.prepended(base)
      base.state_machine.after_transition to: :shipped, do: :create_tax_transaction_async
    end

    private

    def create_tax_transaction_async
      return unless order.fully_shipped?
      return if order.stripe_tax_calculation_id.blank?

      payment_session = order.payment_sessions.where(type: Spree::PaymentSessions::Stripe.name).last
      return if payment_session.blank?

      SpreeStripe::CreateTaxTransactionJob.perform_later(order.store_id, payment_session.stripe_id, order.stripe_tax_calculation_id)
    end
  end
end

Spree::Shipment.prepend(SpreeStripe::ShipmentDecorator) if Spree::Shipment.included_modules.exclude?(SpreeStripe::ShipmentDecorator)
