# Spree Stripe

This is a Stripe extension for [Spree Commerce](https://spreecommerce.org), an open source e-commerce platform built with Ruby on Rails.

## Installation

1. Add this extension to your Gemfile with this line:

    ```ruby
    bundle add spree_stripe
    ```

2. Run the install generator

    ```ruby
    bundle exec rails g spree_stripe:install
    ```

3. Restart your server

  If your server was running, restart it so that it can find the assets properly.

## Developing

1. Create a dummy app

    ```bash
    bundle update
    bundle exec rake test_app
    ```

2. Add your new code
3. Run tests

    ```bash
    bundle exec rspec
    ```

When testing your applications integration with this extension you may use it's factories.
Simply add this require statement to your spec_helper:

```ruby
require 'spree_stripe/factories'
```

## Releasing a new version

```shell
bundle exec gem bump -p -t
bundle exec gem release
```

For more options please see [gem-release README](https://github.com/svenfuchs/gem-release)

## Contributing

If you'd like to contribute, please take a look at the
[instructions](CONTRIBUTING.md) for installing dependencies and crafting a good
pull request.

Copyright (c) 2025 [name of extension creator], released under the New BSD License
