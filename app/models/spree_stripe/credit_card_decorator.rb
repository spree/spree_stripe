module SpreeStripe
  module CreditCardDecorator
    def self.prepended(base)
      base.store_accessor :private_metadata, :wallet
    end

    def wallet_type
      wallet&.[]('type')
    end
  end
end

Spree::CreditCard.prepend(SpreeStripe::CreditCardDecorator)
