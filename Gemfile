source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'rails-controller-testing'

spree_opts = if ENV['SPREE_PATH']
                { 'path': ENV['SPREE_PATH'] }
             else
                { 'github': 'spree/spree', 'branch': 'main' }
             end
gem 'spree', spree_opts
gem 'spree_admin', spree_opts
gem 'spree_emails', spree_opts
gem 'spree_storefront', spree_opts

if ENV['DB'] == 'mysql'
  gem 'mysql2'
elsif ENV['DB'] == 'postgres'
  gem 'pg'
else
  gem 'sqlite3'
end

gem "sprockets-rails", "~> 3.5"

gemspec
