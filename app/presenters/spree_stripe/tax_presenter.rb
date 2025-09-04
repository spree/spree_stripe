module SpreeStripe
  class TaxPresenter
    SHIPPING_TAX_CODE = 'txcd_92010001'.freeze

    def initialize(order:, tax_exclusive: true)
      @order = order
      @tax_exclusive = tax_exclusive
    end

    attr_reader :order, :tax_exclusive

    def call
      {
        currency: order.currency.downcase,
        line_items: build_line_items_attributes(order.line_items, tax_exclusive),
        customer_details: {
          address: build_address_attributes(order.tax_address),
          address_source: 'shipping',
        },
        shipping_cost: {
          amount: calculate_shipping_cost(order.shipments),
          tax_behavior: tax_exclusive.present? ? 'exclusive' : 'inclusive',
          tax_code: SHIPPING_TAX_CODE
        },
        expand: [
          'line_items.data.tax_breakdown',
          'shipping_cost.tax_breakdown'
        ]
      }
    end

    private

    def build_line_items_attributes(line_items, tax_exclusive)
      line_items.map do |line_item|
        attributes = {
          reference: line_item.id,
          tax_behavior: tax_exclusive.present? ? 'exclusive' : 'inclusive',
          amount: line_item.display_amount.cents,
          quantity: line_item.quantity
        }

        tax_code = line_item.product.stripe_tax_code

        attributes.merge!(tax_code: tax_code) if tax_code.present?
        attributes
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
      zero_money = Spree::Money.new(0, currency: shipments.first&.currency)
      shipment_money = shipments.sum(zero_money, &:display_cost)
      shipment_money.cents
    end
  end
end
