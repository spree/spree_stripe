module SpreeStripe
  module CreditCardDecorator
    def self.prepended(base)
      base.store_accessor :private_metadata, :wallet

      # Matches cards by Stripe's stable card fingerprint plus expiry.
      #
      # @param fingerprint [String] Stripe card.fingerprint
      # @param month [Integer, String] expiry month
      # @param year [Integer, String] expiry year
      base.scope :by_fingerprint, ->(fingerprint, month, year) {
        cards_table = Spree::CreditCard.table_name

        where(fingerprint: fingerprint).
          where("CAST(#{cards_table}.month AS DECIMAL) = ?", month).
          where("CAST(#{cards_table}.year AS DECIMAL) = ?", year)
      }
    end

    def wallet_type
      wallet&.[]('type')
    end
  end
end

Spree::CreditCard.prepend(SpreeStripe::CreditCardDecorator)
