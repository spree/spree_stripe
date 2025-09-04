module SpreeStripe
  module Calculators
    class StripeTax < ::Spree::Calculator
      def self.description
        'Stripe tax calculator'
      end

      def compute_line_item(line_item)
        order = line_item.order
        return 0.to_d unless stripe_tax_enabled?(order)

        tax_calculation_data = get_or_create_tax_calculation(order)
        return 0.to_d unless tax_calculation_data.present?

        # Find the tax line for this specific line item
        stripe_line_item = tax_calculation_data.line_items.data.find do |line|
          line.reference.to_s == line_item.id.to_s
        end

        return 0.to_d unless stripe_line_item.present?

        # Get the tax amount for this line item
        amount_in_cents = stripe_line_item.tax_breakdown.sum(&:amount)
        amount_money = Spree::Money.from_cents(amount_in_cents, { currency: order.currency })
        amount_money.to_d
      end

      def compute_shipment(shipment)
        order = shipment.order
        return 0.to_d unless stripe_tax_enabled?(order)

        tax_calculation_data = get_or_create_tax_calculation(order)
        return 0.to_d unless tax_calculation_data.present?

        # Get the shipping cost tax breakdown
        shipping_cost = tax_calculation_data.shipping_cost
        return 0.to_d unless shipping_cost.present?

        # Get the tax amount for shipping
        amount_in_cents = shipping_cost.amount_tax
        amount_money = Spree::Money.from_cents(amount_in_cents, { currency: order.currency })
        amount_money.to_d
      end

      private

      def stripe_tax_enabled?(order)
        stripe_gateway = order.store.stripe_gateway
        stripe_gateway.present? && stripe_gateway.active?
      end

      def get_or_create_tax_calculation(order)
        stripe_gateway = order.store.stripe_gateway

        Rails.cache.fetch("stripe_tax_calculation_#{order.item_total}_#{order.shipment_total}_#{order.item_count}", expires_in: 1.hour) do
          stripe_gateway.create_tax_calculation(order)
        end
      rescue => e
        Rails.logger.error "Stripe Tax calculation failed: #{e.message}"
        nil
      end

      def find_stripe_tax_line(stripe_tax_lines, line_item_id)
        # Find the tax line that matches the specific line item by reference (line item ID)
        stripe_tax_lines.find do |stripe_tax_line|
          stripe_tax_line.reference.to_s == line_item_id.to_s
        end
      end
    end
  end
end
