module SpreeStripe
  class AttachCustomerToCreditCardJob < BaseJob
    def perform(gateway_id, user_id)
      return unless Spree.user_class.present?

      gateway = SpreeStripe::Gateway.find_by(id: gateway_id)
      puts "GATEWAY: #{gateway.inspect}"
      return if gateway.blank?

      user = Spree.user_class.find_by(id: user_id)
      puts "USER: #{user.inspect}"
      return if user.blank?

      gateway.attach_customer_to_credit_card(user)
    end
  end
end
