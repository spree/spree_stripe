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
        line_items = tax_calculation_data.dig('line_items', 'data') || []
        stripe_line_item = line_items.find do |line|
          line['reference'].to_s == line_item.id.to_s
        end

        # Debug logging
        if stripe_line_item.nil?
          Rails.logger.debug "Stripe Tax: No line item found for reference #{line_item.id}. Available references: #{line_items.map { |li| li['reference'] }.join(', ')}"
          return 0.to_d
        end

        # Get the tax amount for this line item from amount_tax field
        amount_in_cents = stripe_line_item['amount_tax'] || 0
        Rails.logger.debug "Stripe Tax: Line item #{line_item.id} tax amount: #{amount_in_cents} cents"
        amount_money = Spree::Money.from_cents(amount_in_cents, { currency: order.currency })
        amount_money.to_d
      end

      def compute_shipment(shipment)
        order = shipment.order
        return 0.to_d unless stripe_tax_enabled?(order)

        tax_calculation_data = get_or_create_tax_calculation(order)
        return 0.to_d unless tax_calculation_data.present?

        # Get the shipping cost tax breakdown
        shipping_cost = tax_calculation_data['shipping_cost']
        return 0.to_d unless shipping_cost.present?

        # Get the tax amount for shipping
        amount_in_cents = shipping_cost['amount_tax'] || 0
        amount_money = Spree::Money.from_cents(amount_in_cents, { currency: order.currency })
        amount_money.to_d
      end

      private

      def stripe_tax_enabled?(order)
        stripe_gateway = order.store.stripe_gateway
        stripe_gateway.present? && stripe_gateway.active?
      end

      def get_or_create_tax_calculation(order)
        return unless order.tax_address.present?
        return if order.state.in?(%w[cart address])

        stripe_gateway = order.store.stripe_gateway

        cache_key = [
          order.number,
          order.currency,
          order.item_total,
          order.item_count,
          order.line_items.map { |li| [li.id, li.quantity].compact }.flatten.join('_'),
          order.shipments.map { |s| [s.shipping_method&.id, s.cost].compact }.flatten.join('_'),
          order.tax_address&.cache_key_with_version,
        ].compact.join('_')

        tax_calculation = Rails.cache.fetch("stripe_tax_calculation_#{cache_key}", expires_in: 1.hour) do
           stripe_gateway.create_tax_calculation(order).to_hash.deep_stringify_keys
        rescue => e
          Rails.error.report(e, context: { order_id: order.id }, source: 'spree_stripe')
          {}
        end

        return nil unless tax_calculation.present?

        # persist the tax calculation in the order for future use
        # we will need this to create tax transaction
        order.stripe_tax_calculation_id = tax_calculation['id']
        order.save!

        tax_calculation
      rescue => e
        Rails.error.report(e, context: { order_id: order.id }, source: 'spree_stripe')
        nil
      end

    end
  end
end
