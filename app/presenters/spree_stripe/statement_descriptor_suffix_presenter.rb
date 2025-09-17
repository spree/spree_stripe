module SpreeStripe
  class StatementDescriptorSuffixPresenter
    STATEMENT_DESCRIPTOR_MAX_CHARS = 10
    STATEMENT_DESCRIPTOR_NOT_ALLOWED_CHARS = /[<>'"*\\]/.freeze

    def initialize(order_description:)
      @order_description = order_description.to_s
    end

    def call
      AnyAscii.transliterate(order_description)
              .gsub(STATEMENT_DESCRIPTOR_NOT_ALLOWED_CHARS, '')
              .strip
              .upcase[0...STATEMENT_DESCRIPTOR_MAX_CHARS]
    end

    private

    attr_reader :order_description
  end
end