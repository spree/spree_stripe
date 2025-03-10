module SpreeStripe
  module UserDecorator
    def self.prepended(base)
      base.has_many :stripe_customers, class_name: 'SpreeStripe::Customer'
    end
  end
end

Spree.user_class.prepend(SpreeStripe::UserDecorator) if Spree.user_class.present?
