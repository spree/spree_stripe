module SpreeStripe
  class Gateway < ::Spree::Gateway
    module PaymentSessions
      extend ActiveSupport::Concern

      def session_required?
        !SpreeStripe::Config[:use_legacy_payment_intents]
      end

      def payment_session_class
        Spree::PaymentSessions::Stripe
      end

      def create_payment_session(order:, amount: nil, external_data: {})
        total = amount.presence || order.total_minus_store_credits
        amount_in_cents = Spree::Money.new(total, currency: order.currency).cents

        return nil if amount_in_cents.zero?

        customer = fetch_or_create_customer(order: order)
        stripe_pm_id = external_data[:stripe_payment_method_id] || external_data['stripe_payment_method_id']

        response = create_payment_intent(
          amount_in_cents, order,
          payment_method_id: stripe_pm_id,
          customer_profile_id: customer&.profile_id
        )

        ephemeral_key_response = create_ephemeral_key(customer.profile_id) if customer.present?
        ephemeral_key_secret = ephemeral_key_response&.params&.dig('secret')

        payment_session_class.create!(
          order: order,
          payment_method: self,
          amount: total,
          currency: order.currency,
          status: 'pending',
          external_id: response.authorization,
          customer: order.user,
          customer_external_id: customer&.profile_id,
          external_data: {
            'client_secret' => response.params['client_secret'],
            'ephemeral_key_secret' => ephemeral_key_secret,
            'stripe_payment_method_id' => stripe_pm_id
          }.compact
        )
      end

      def update_payment_session(payment_session:, amount: nil, external_data: {})
        attrs = {}
        amount_in_cents = nil

        if amount.present?
          attrs[:amount] = amount
          amount_in_cents = Spree::Money.new(amount, currency: payment_session.currency).cents
        end

        stripe_pm_id = external_data[:stripe_payment_method_id] || external_data['stripe_payment_method_id']

        update_payment_intent(
          payment_session.external_id,
          amount_in_cents || payment_session.amount_in_cents,
          payment_session.order,
          stripe_pm_id
        )

        if external_data.present?
          attrs[:external_data] = (payment_session.external_data || {}).merge(external_data.stringify_keys)
        end

        payment_session.update!(attrs) if attrs.any?
      end

      # Completes a payment session by verifying with Stripe, creating the
      # Payment record, and patching wallet address data.
      #
      # Does NOT complete the order — that is handled by Carts::Complete
      # (called by the storefront or by the webhook handler).
      def complete_payment_session(payment_session:, params: {})
        stripe_pi = retrieve_payment_intent(payment_session.external_id)

        if payment_intent_accepted?(stripe_pi)
          payment_session.process if payment_session.can_process?

          charge = payment_session.stripe_charge

          # Patch wallet billing address (Apple Pay, Google Pay)
          patch_wallet_address(payment_session.order, charge) if charge.present?

          # Create the Payment record
          payment_session.find_or_create_payment!

          # Process the payment state
          payment = payment_session.payment
          if payment.present? && !payment.completed?
            if payment_intent_successful?(stripe_pi)
              payment.process!
            else
              payment.authorize!
            end
          end

          payment_session.complete unless payment_session.completed?
        else
          payment_session.fail if payment_session.can_fail?
        end
      end

      private

      def payment_intent_successful?(stripe_pi)
        stripe_pi.status == 'succeeded'
      end

      # Patches the order's billing address with data from the Stripe charge.
      # Needed for quick checkout (Apple Pay/Google Pay) where the storefront
      # doesn't have the billing address before payment confirmation.
      def patch_wallet_address(order, charge)
        return if charge.blank?

        billing_details = charge.billing_details
        address = billing_details.address

        order.email ||= billing_details.email
        order.save! if order.email_changed?

        # Skip if billing address is already valid
        return if order.bill_address.present? && order.bill_address.valid?

        country_iso = address.country
        country = Spree::Country.find_by(iso: country_iso) || Spree::Country.default

        order.bill_address ||= Spree::Address.new(country: country, user: order.user)
        order.bill_address.quick_checkout = true

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
          order.bill_address.state = country.states.find_all_by_name_or_abbr(state_name)&.first
        else
          order.bill_address.state_name = state_name
        end
        order.bill_address.state_name ||= state_name

        if order.bill_address.invalid?
          return if order.ship_address.blank?

          order.bill_address = order.ship_address
        end

        order.bill_address.save! if order.bill_address&.changed?
        order.save!

        copy_bill_info_to_user(order) if order.user.present?
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
end
