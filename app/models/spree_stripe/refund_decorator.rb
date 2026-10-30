module SpreeStripe
  module RefundDecorator
    def self.prepended(base)
      base.store_accessor :private_metadata, :stripe_tax_reversal_id

      base.after_create :create_tax_reversal_async
    end

    def create_tax_reversal_async
      return unless payment.payment_method.is_a?(SpreeStripe::Gateway)
      return if payment.stripe_tax_transaction_id.blank?
      return if stripe_tax_reversal_id.present?

      SpreeStripe::CreateTaxReversalJob.perform_later(id)
    end
  end
end

Spree::Refund.prepend(SpreeStripe::RefundDecorator) if Spree::Refund.included_modules.exclude?(SpreeStripe::RefundDecorator)
