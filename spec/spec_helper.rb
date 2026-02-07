# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require 'dotenv/load'

require File.expand_path('../dummy/config/environment.rb', __FILE__)

require 'spree_dev_tools/rspec/spec_helper'
require 'spree_stripe/factories'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].sort.each { |f| require f }

require 'jsonapi/rspec'
require 'spree_legacy_api_v2/testing_support/v2/base'
require 'spree_legacy_api_v2/testing_support/factories'
require 'spree_legacy_api_v2/testing_support/v2/current_order'
require 'spree_legacy_api_v2/testing_support/v2/platform_contexts'
require 'spree_legacy_api_v2/testing_support/v2/serializers_params'

def json_response
  case body = JSON.parse(response.body)
  when Hash
    body.with_indifferent_access
  when Array
    body
  end
end

RSpec.configure do |config|
  config.include JSONAPI::RSpec, type: :request # required for API v2 request specs
end
