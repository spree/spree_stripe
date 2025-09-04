module SpreeStripe
  class TaxPresenter
    SHIPPING_TAX_CODE = 'txcd_92010001'.freeze
    TAX_BEHAVIOR = 'exclusive'.freeze

    def initialize(order:)
      @order = order
    end

    attr_reader :order

    def call
      {
        currency: order.currency.downcase,
        line_items: build_line_items_attributes(order.line_items),
        customer_details: {
          address: build_address_attributes(order.tax_address),
          address_source: 'shipping',
        },
        shipping_cost: {
          amount: calculate_shipping_cost(order.shipments),
          tax_behavior: TAX_BEHAVIOR,
          tax_code: SHIPPING_TAX_CODE
        },
        expand: [
          'line_items.data.tax_breakdown',
          'shipping_cost.tax_breakdown'
        ]
      }
    end

    private

    def build_line_items_attributes(line_items)
      line_items.map do |line_item|
        {
          reference: line_item.id,
          tax_behavior: TAX_BEHAVIOR,
          amount: line_item.display_amount.cents,
          quantity: line_item.quantity
        }
      end
    end

    def build_address_attributes(address)
      return {} if address.blank?

      {
        line1: address.address1,
        city: address.city,
        state: address.state,
        postal_code: address.zipcode,
        country: address.country_iso
      }
    end

    def calculate_shipping_cost(shipments)
      zero_money = Spree::Money.new(0, currency: order.currency)
      shipment_money = shipments.sum(zero_money, &:display_cost)
      shipment_money.cents
    end
  end
end
