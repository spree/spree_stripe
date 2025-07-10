module SpreeStripe
  module AddressDecorator
    def self.prepended(base)
      base.after_update :update_stripe_customer, if: :should_update_stripe_customer?
    end

    delegate :update_stripe_customer, to: :user, allow_nil: true

    private

    def should_update_stripe_customer?
      user_default_billing? && previous_changes.any?
    end
  end
end

if ActiveRecord::Base.connection.database_exists? && ActiveRecord::Base.connection.table_exists?('spree_addresses')
  Spree::Address.prepend(SpreeStripe::AddressDecorator)
end
