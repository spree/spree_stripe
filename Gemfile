source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'rails-controller-testing'

spree_opts = if ENV['SPREE_PATH']
                { 'path': ENV['SPREE_PATH'] }
             else
                { 'github': 'spree/spree', 'branch': 'main', 'glob': 'spree/**/*.gemspec' }
             end
gem 'spree', spree_opts

# spree_admin pinned to the commit before spree#14287, which added a
# Spree::Admin::StorefrontController + `admin_storefront` route that collides
# with spree_page_builder's. Revert to spree_opts once upstream deconflicts.
spree_admin_opts = if ENV['SPREE_PATH']
                      { 'path': ENV['SPREE_PATH'] }
                   else
                      { 'github': 'spree/spree', 'ref': '2174f67734f523207bb90d6cdf4eb7463619af52', 'glob': 'spree/admin/*.gemspec' }
                   end
gem 'spree_admin', spree_admin_opts

gem 'spree_custom_domains', github: 'spree/spree_custom_domains', branch: 'main'

spree_storefront_opts = { 'github': 'spree/spree-rails-storefront', 'branch': 'main' }
gem 'spree_page_builder', spree_storefront_opts
gem 'spree_storefront', spree_storefront_opts

gem 'spree_dev_tools', '>= 0.6.0.rc1'

if ENV['DB'] == 'mysql'
  gem 'mysql2'
elsif ENV['DB'] == 'postgres'
  gem 'pg'
else
  gem 'sqlite3'
end

gem 'propshaft'

gemspec
