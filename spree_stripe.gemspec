# encoding: UTF-8
lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'spree_stripe/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_stripe'
  s.version     = SpreeStripe::VERSION
  s.summary     = "Official Spree Commerce Stripe payment gateway extension"
  s.required_ruby_version = '>= 3.0'

  s.author    = 'Vendo Connect Inc.'
  s.email     = 'hello@spreecommerce.org'
  s.homepage  = 'https://github.com/spree/spree_stripe'
  s.license = 'AGPL-3.0-or-later'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree', '>= 5.0.0.alpha'
  s.add_dependency 'spree_storefront', '>= 5.0.0.alpha'
  s.add_dependency 'spree_admin', '>= 5.0.0.alpha'
  s.add_dependency 'spree_extension'

  s.add_dependency 'stripe', '~> 10.1.0'
  s.add_dependency 'stripe_event', '~> 2.11'

  s.add_development_dependency 'spree_dev_tools'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'webmock'
end
