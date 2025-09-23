module SpreeStripe
  class StatementDescriptorSuffixPresenter
    STATEMENT_DESCRIPTOR_MAX_CHARS = 10
    STATEMENT_DESCRIPTOR_NOT_ALLOWED_CHARS = /[<>'"*\\]/.freeze
    STATEMENT_PREFIX = 'O#'

    def initialize(order_description:)
      @order_description = order_description.to_s
    end

    def call
      return if stripped_order_description.blank?

      if stripped_order_description.count("A-Z") > 0
        stripped_order_description
      else
        "#{STATEMENT_PREFIX}#{stripped_order_description}"[0...STATEMENT_DESCRIPTOR_MAX_CHARS].strip
      end
    end

    private

    attr_reader :order_description

    def stripped_order_description
      @stripped_order_description ||= begin
        AnyAscii.transliterate(order_description)
                .gsub(STATEMENT_DESCRIPTOR_NOT_ALLOWED_CHARS, '')
                .strip
                .upcase[0...STATEMENT_DESCRIPTOR_MAX_CHARS]
                .strip
      end
    end
  end
end