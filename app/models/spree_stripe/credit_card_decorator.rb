module SpreeStripe
  # Backports Stripe's credit-card fingerprint dedup onto Spree::CreditCard for
  # spree < 5.6.0, which doesn't ship it. spree >= 5.6.0 provides the column,
  # scope, and validation in core, so this is only prepended (below) when core
  # lacks it. (Wallet metadata accessors already live in core since 5.4, so they
  # don't need backporting here.)
  module CreditCardDecorator
    def self.prepended(base)
      # Matches saved cards by the gateway's stable card fingerprint plus expiry,
      # used to reuse an existing card instead of saving a duplicate when a gateway
      # issues a fresh payment method id for the same physical card.
      #
      # @param fingerprint [String] gateway card fingerprint
      # @param month [Integer, String] expiry month
      # @param year [Integer, String] expiry year
      base.scope :by_fingerprint, ->(fingerprint, month, year) {
        cards_table = Spree::CreditCard.table_name

        where(fingerprint: fingerprint).
          where("CAST(#{cards_table}.month AS DECIMAL) = ?", month).
          where("CAST(#{cards_table}.year AS DECIMAL) = ?", year)
      }

      # Prevents saving the same physical card (same gateway fingerprint + expiry)
      # twice for a user and payment method. Skipped when the gateway does not
      # provide a fingerprint.
      base.validate :fingerprint_not_duplicated, if: -> { fingerprint.present? }
    end

    private

    # month/year are varchar columns exposed as integer attributes, so the
    # match must go through #by_fingerprint's decimal cast rather than a plain
    # equality (which Postgres rejects as `character varying = integer`).
    def fingerprint_not_duplicated
      duplicates = self.class.where(user_id: user_id, payment_method_id: payment_method_id).
                   by_fingerprint(fingerprint, month, year)
      duplicates = duplicates.where.not(id: id) if persisted?

      errors.add(:fingerprint, :taken) if duplicates.exists?
    end
  end
end

# spree >= 5.6.0 ships fingerprint dedup in core, so only prepend the backport
# when it's absent (spree < 5.6.0).
unless Spree::CreditCard.respond_to?(:by_fingerprint)
  Spree::CreditCard.prepend(SpreeStripe::CreditCardDecorator)
end
