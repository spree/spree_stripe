module SpreeStripe
  module StoreControllerDecorator
    def self.prepended(base)
      base.helper SpreeStripe::BaseHelper
    end
  end
end

if defined?(Spree::StoreController)
  Spree::StoreController.prepend(SpreeStripe::StoreControllerDecorator) if defined?(Spree::StoreController)
end
