module SpreeStripe
  module Calculators
    class StripeTax < ::Spree::Calculator
      def self.description
        'Stripe tax calculator'
      end

      def compute_order(order)
        stripe_gateway = order.store.stripe_gateway
        return 0.to_d unless stripe_gateway.present?

        tax_calculation = stripe_gateway.create_tax_calculation(order)

        tax_lines = tax_calculation.fetch('tax_breakdown', [])
        tax_line = find_tax_line(tax_lines)

        return 0.to_d unless tax_line.present?

        amount_in_cents = tax_line.fetch('amount', 0)
        amount_money = Spree::Money.from_cents(amount_in_cents)

        amount_money.to_d
      end

      def compute_line_item(line_item)
        order = line_item.order
        tax_calculation_data = order.stripe_tax_calculation
        return 0.to_d unless tax_calculation_data.present?

        stripe_tax_calculation = SpreeStripe::SalesTaxTransaction.new(data: tax_calculation_data)
        stripe_tax_lines = stripe_tax_calculation.line_item_tax_lines(line_item.id)

        stripe_tax_line = find_stripe_tax_line(stripe_tax_lines)

        return 0.to_d unless stripe_tax_line.present?

        amount_money = Spree::Money.from_cents(stripe_tax_line.amount_in_cents)
        amount_money.to_d
      end

      def compute_shipment(shipment)
        tax_amount = shipment.discounted_cost * calculable.amount
        tax_amount.to_d.round(2, BigDecimal::ROUND_HALF_UP)
      end

      private

      def find_stripe_tax_line(stripe_tax_lines)
        stripe_tax_lines.find do |stripe_tax_line|
          percentage_decimal = stripe_tax_line.percentage_decimal
          tax_inclusive = stripe_tax_line.inclusive

          calculable.included_in_price == tax_inclusive && percentage_decimal == calculable.amount * 100
        end
      end
    end
  end
end
