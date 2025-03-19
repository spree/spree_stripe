# Spree Stripe

This is the official Stripe payment gateway extension for [Spree Commerce](https://spreecommerce.org) open-source eCommerce platform. 

> [!IMPORTANT]
> This Stripe integration for Spree is free to use for private projects but requires a [Commercial License](https://spreecommerce.org/why-consider-a-commercial-license-for-your-multi-tenant-or-saas-spree-based-project/) if you're planning to use it for your [SaaS](https://spreecommerce.org/multi-tenant-white-label-ecommerce/) or a [multi-tenant eCommerce](https://spreecommerce.org/multi-tenant-white-label-ecommerce/) website. 
> Feel free to [reach out](https://spreecommerce.org/get-started/) to learn more.

> [!TIP]
> Looking for a [Stripe Connect integration](#looking-for-a-stripe-connect-integration-for-spree) for Spree? It's available with the [Enterprise Edition](https://spreecommerce.org/spree-commerce-version-comparison-community-edition-vs-enterprise-edition/).

## Features

- Support for off-session payments
- Support for quick checkout
- Support for 3D Secure and other security standards
- Support for Storefront API integration (see the API docs [here](https://spreecommerce.org/docs/api-reference/storefront/stripe)).
- Accept payments in over 130 currencies
- Accept Credit Cards, Apple Pay, Google Pay, and more
- Accept SEPA Direct Debit payments
- Accept iDEAL payments
- Accept SOFORT payments
- Accept Bancontact payments
- Accept Alipay payments
- Accept WeChat Pay payments
- Accept Afterpay, Klarna, Affirm, and more

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

Copyright (c) 2025 [Vendo Connect Inc.](https://getvendo.com), released under [AGPL 3.0 license](https://github.com/spree/spree_stripe/blob/main/LICENSE.md). Please refer to [this blog post](https://spreecommerce.org/why-spree-is-changing-its-open-source-license-to-agpl-3-0-and-introducing-a-commercial-license/) and [that blog post](https://spreecommerce.org/open-source-ecommerce-transparency/) to learn more about Spree licensing. 

## Looking for a Stripe Connect integration for Spree?

Spree Commerce [Enterprise Edition](https://spreecommerce.org/spree-commerce-version-comparison-community-edition-vs-enterprise-edition/) comes with a fully automated Stripe Connect integration for a [multi-vendor marketplace use case](https://spreecommerce.org/marketplace-ecommerce/):

- Automated split payments between marketplace and vendors
- Support for multiple payment methods including cards and digital wallets
- Configurable marketplace fees and commission structures
- Automated payouts to vendors
- Comprehensive transaction reporting
- Built-in fraud prevention tools

Feel free to [reach out](https://spreecommerce.org/get-started/) to learn more.
