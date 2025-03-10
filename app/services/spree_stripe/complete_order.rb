module SpreeStripe
  class CompleteOrder
    def initialize(payment_intent:)
      @payment_intent = payment_intent
    end

    attr_reader :payment_intent

    def call
      order = payment_intent.order

      return order if order.completed? || order.canceled?

      charge = payment_intent.stripe_charge

      order.with_lock do
        # needed for quick checkout orders
        order = add_customer_information(order, charge)

        # find or create the payment
        payment = payment_intent.find_or_create_payment!

        # process the payment
        payment.process!

        # complete the order
        Spree::Dependencies.checkout_complete_service.constantize.call(order: order)
      end

      order.reload
    end

    private

    # we need to perform this for quick checkout orders which do not have these fields filled
    def add_customer_information(order, charge)
      billing_details = charge.billing_details
      address = billing_details.address

      order.email ||= billing_details.email
      order.save! if order.email_changed?

      # we don't need to perform this if we already have the billing address filled
      return order if order.bill_address.present? && order.bill_address.valid?

      # determine country...
      country_iso = address.country
      country = Spree::Country.find_by(iso: country_iso) || Spree::Country.default

      # assign new address if we don't have one
      order.bill_address ||= Spree::Address.new(country: country, user: order.user)

      # assign attributes
      order.bill_address.quick_checkout = true # skipping some validations

      # sometimes google pay doesn't provide name (geez)
      first_name = billing_details.name&.split(' ')&.first || order.ship_address&.first_name || order.user&.first_name
      last_name = billing_details.name&.split(' ')&.last || order.ship_address&.last_name || order.user&.last_name

      order.bill_address.first_name ||= first_name
      order.bill_address.last_name ||= last_name
      order.bill_address.phone ||= billing_details.phone
      order.bill_address.address1 ||= address.line1
      order.bill_address.address2 ||= address.line2
      order.bill_address.city ||= address.city
      order.bill_address.zipcode ||= address.postal_code

      state_name = address.state
      if country.states_required?
        order.bill_address.state = country.states.find_all_by_name_or_abbr(state_name)&.first if country.states_required?
      else
        order.bill_address.state_name = state_name
      end

      order.bill_address.state_name ||= state_name

      if order.bill_address.invalid?
        order.bill_address = order.ship_address
      else
        order.bill_address.save!
      end

      order.save!

      copy_bill_info_to_user(order) if order.user.present?

      order
    end

    def copy_bill_info_to_user(order)
      user = order.user
      user.first_name ||= order.bill_address.first_name
      user.last_name ||= order.bill_address.last_name
      user.phone ||= order.bill_address.phone
      user.bill_address_id ||= order.bill_address.id
      user.save! if user.changed?
    end
  end
end
