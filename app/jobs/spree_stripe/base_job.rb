module SpreeStripe
  class BaseJob < Spree::BaseJob
    queue_as Spree.queues.stripe
  end
end
