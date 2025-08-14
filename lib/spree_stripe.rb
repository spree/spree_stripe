require 'spree_core'
require 'spree_extension'
require 'spree_stripe/engine'
require 'spree_stripe/version'
require 'spree_stripe/configuration'

require 'stripe'
require 'stripe_event'

module SpreeStripe
  mattr_accessor :queue

  def self.queue
    @@queue ||= Spree.queues.default
  end
end
