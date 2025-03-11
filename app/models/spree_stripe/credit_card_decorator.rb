module SpreeStripe
  module CreditCardDecorator
    def self.prepended(base)
      base.belongs_to :customer, class_name: 'SpreeStripe::Customer', optional: true
      base.store_accessor :private_metadata, :wallet
    end

    def wallet_type
      wallet&.[]('type')
    end
  end
end

Spree::CreditCard.prepend(SpreeStripe::CreditCardDecorator)
