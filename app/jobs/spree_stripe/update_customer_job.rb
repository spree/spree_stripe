module SpreeStripe
  class UpdateCustomerJob < BaseJob
    def perform(user_id)
      return unless Spree.user_class.present?

      user = Spree.user_class.find(user_id)
      SpreeStripe::UpdateCustomer.new.call(user: user)
    end
  end
end
