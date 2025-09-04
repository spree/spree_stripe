module SpreeStripe
  class SalesTaxTransaction
    TaxLine = Struct.new(:country, :state, :percentage_decimal, :amount_in_cents, :inclusive, keyword_init: true)

    def initialize(data:)
      @data = data || {}
    end

    def id
      data.fetch('id', nil)
    end

    def tax_line_item_id(reference_id)
      line_items = data.dig('line_items', 'data') || []
      line_item = line_items.find { |item| item['reference'] == reference_id } || {}

      line_item['id']
    end

    def line_item_tax_money(reference_id, quantity = nil)
      line_items = data.dig('line_items', 'data') || []
      line_item = line_items.find { |item| item['reference'] == reference_id }

      return Spree::Money.new(0) if line_item.nil?

      total_tax_cents = line_item['amount_tax']
      max_quantity = line_item['quantity']
      quantity ||= max_quantity

      tax_cents = ((quantity / max_quantity.to_d) * total_tax_cents).round(2, BigDecimal::ROUND_HALF_UP)
      Spree::Money.from_cents(tax_cents)
    end

    def line_item_tax_lines(reference_id)
      line_items = data.dig('line_items', 'data') || []
      line_item = line_items.find { |item| item['reference'].to_s == reference_id.to_s }

      return [] if line_item.nil?

      build_tax_lines(line_item['tax_breakdown'], line_item['tax_behavior'])
    end

    def shipping_tax_lines
      shipping_cost = data.fetch('shipping_cost', {})
      return [] if shipping_cost.empty?

      shipping_tax = shipping_cost.fetch('amount_tax', 0)
      return [] if shipping_tax.zero?

      build_tax_lines(shipping_cost['tax_breakdown'], shipping_cost['tax_behavior'])
    end

    def shipping_tax_money(from_amount_in_cents)
      shipping_cost = data.fetch('shipping_cost', {})
      return Spree::Money.new(0) if shipping_cost.empty? || from_amount_in_cents.zero?

      shipping_amount = shipping_cost.fetch('amount', 0)
      shipping_tax = shipping_cost.fetch('amount_tax', 0)

      return Spree::Money.new(0) if shipping_amount.zero? || shipping_tax.zero?

      tax_cents = ((from_amount_in_cents / shipping_amount.to_d) * shipping_tax).round(2, BigDecimal::ROUND_HALF_UP)
      tax_cents = [tax_cents, shipping_tax.to_d].min

      Spree::Money.from_cents(tax_cents)
    end

    def total_tax_money
      line_items = data.dig('line_items', 'data') || []
      shipping_cost = data.fetch('shipping_cost', {})

      line_item_total_tax = line_items.sum(0) { |line_item| line_item['amount_tax'].abs }
      shipping_total_tax = shipping_cost.fetch('amount_tax', 0)

      total_tax = line_item_total_tax + shipping_total_tax

      Spree::Money.from_cents(total_tax)
    end

    private

    attr_reader :data

    def build_tax_lines(tax_breakdown, tax_behavior)
      grouped_tax_lines = tax_breakdown.group_by do |tax_line|
        {
          'country' => tax_line.dig('jurisdiction', 'country'),
          'state' => tax_line.dig('jurisdiction', 'state')
        }
      end

      grouped_tax_lines.map do |jurisdiction, tax_lines|
        percentage_decimal = tax_lines.sum(0.to_d) { |tax_line| tax_line.dig('tax_rate_details', 'percentage_decimal').to_d }
        amount_in_cents = tax_lines.sum(0) { |tax_line| tax_line['amount'].to_i }

        TaxLine.new(
          country: jurisdiction['country'],
          state: jurisdiction['state'],
          percentage_decimal: percentage_decimal,
          amount_in_cents: amount_in_cents,
          inclusive: tax_behavior == 'inclusive'
        )
      end
    end
  end
end
