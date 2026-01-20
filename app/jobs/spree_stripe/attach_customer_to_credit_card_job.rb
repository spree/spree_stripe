module SpreeStripe
  class AttachCustomerToCreditCardJob < BaseJob
    def perform(order_id)
      return if Spree.user_class.blank?

      order = Spree::Order.find_by(id: order_id)
      return if order.blank? || order.user_id.blank?

      gateway = order.store.stripe_gateway
      return if gateway.blank?

      user = Spree.user_class.find_by(id: order.user_id)
      return if user.blank?

      gateway.attach_customer_to_credit_card(user)
    end
  end
end
