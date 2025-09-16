module SpreeStripe
  class PaymentIntentPresenter
    SETUP_FUTURE_USAGE = 'off_session'

    def initialize(amount:, order:, customer: nil, payment_method_id: nil, off_session: false)
      @amount = amount
      @order = order
      @customer = customer
      @ship_address = order.ship_address
      @payment_method_id = payment_method_id
      @off_session = off_session
    end

    def call
      payload = if payment_method_id.present?
                  saved_payment_method_payload
                else
                  new_payment_method_payload
                end

      payload = payload.deep_merge(basic_payload)

      return payload unless ship_address

      # we don't validate address1, but it's required by Stripe
      if ship_address.invalid? || ship_address.address1.blank?
        ship_address.errors.clear
        return payload
      end

      payload.merge(ship_address_payload)
    end

    def ship_address_payload
      {
        shipping: {
          address: {
            city: ship_address.city,
            country: ship_address.country_iso,
            line1: ship_address.address1,
            line2: ship_address.address2,
            postal_code: ship_address.zipcode,
            state: ship_address.state_abbr
          },
          name: ship_address.full_name
        }
      }
    end

    private

    attr_reader :order, :amount, :customer, :ship_address, :payment_method_id

    def basic_payload
      {
        amount: amount,
        customer: customer,
        currency: order.currency,
        statement_descriptor_suffix: statement_descriptor,
        automatic_payment_methods: {
          enabled: true
        },
        transfer_group: order.number,
        metadata: {
          spree_order_id: order.id
        }
      }
    end

    def statement_descriptor
      SpreeStripe::StatementDescriptorPresenter.new(
        order_number: order.number,
        store_billing_name: order.store.name
      ).call
    end

    def new_payment_method_payload
      {
        payment_method_options: {
          card: {
            setup_future_usage: SETUP_FUTURE_USAGE
          }
        }
      }
    end

    def saved_payment_method_payload
      {
        payment_method: payment_method_id,
        off_session: @off_session,
        confirm: @off_session # confirm is required for off_session payments
      }
    end
  end
end
