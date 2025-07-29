module SpreeStripe
  module CheckoutHelperDecorator
    def checkout_payment_sources(payment_method = nil)
      payment_sources = super(payment_method)
      return payment_sources if payment_sources.empty? || !payment_method.stripe?

      wallet_sources, non_wallet_sources = payment_sources.partition { |source| source.wallet_type.present? }
      unique_wallet_sources = wallet_sources.sort_by(&:created_at).reverse.uniq { |source| [source.wallet_type, source.cc_type, source.last_digits, source.month, source.year] }

      non_wallet_sources + unique_wallet_sources
    end
  end
end

Spree::CheckoutHelper.prepend(SpreeStripe::CheckoutHelperDecorator)
