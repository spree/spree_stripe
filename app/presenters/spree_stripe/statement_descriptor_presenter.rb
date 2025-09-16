module SpreeStripe
  class StatementDescriptorPresenter
    STATEMENT_DESCRIPTOR_MAX_CHARS = 22
    STATEMENT_DESCRIPTOR_NOT_ALLOWED_CHARS = /[<>'"*\\]/.freeze

    def initialize(order_number:, store_billing_name:)
      @order_number = order_number
      @store_billing_name = store_billing_name
    end

    def call
      descriptor[0...STATEMENT_DESCRIPTOR_MAX_CHARS].strip.upcase
    end

    private

    attr_reader :order_number, :store_billing_name

    def descriptor
      I18n.transliterate("#{order_number} #{store_billing_name.strip}")
          .gsub(STATEMENT_DESCRIPTOR_NOT_ALLOWED_CHARS, '')
    end
  end
end