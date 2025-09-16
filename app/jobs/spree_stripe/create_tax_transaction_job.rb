module SpreeStripe
  class CreateTaxTransactionJob < ApplicationJob
    def perform(store_id, payment_intent_id, tax_calculation_id)
      store = Spree::Store.find(store_id)
      gateway = store.stripe_gateway

      gateway.create_tax_transaction(payment_intent_id, tax_calculation_id) if gateway.present?
    end
  end
end
