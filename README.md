<p align="center">
  <a href="https://spreecommerce.org">
    <img alt="Spree Commerce x Stripe integration" src="https://vendo-production-res.cloudinary.com/image/upload/w_2000/q_auto/v1742930549/docs/github/Spree_Commerce_open-source_eCommerce_Stripe_payments_integration_-_Github_xlrcn8.jpg">
  </a>

# Spree Stripe

This is the official Stripe payment gateway extension for [Spree Commerce](https://spreecommerce.org) [open-source eCommerce platform](https://spreecommerce.org/). 

This Stripe integration is bundled in the [Spree Starter](https://github.com/spree/spree_starter/) for your development convenience. 

Or you could follow the [installation instructions](https://spreecommerce.org/docs/integrations/payments/stripe).

If you like what you see, consider giving this repo a GitHub star :star:

Thank you for supporting Spree open-source :heart:

> [!TIP]
> Looking for a [Stripe Connect integration](#looking-for-a-stripe-connect-integration-for-spree) for Spree? It's available with the [Enterprise Edition](https://spreecommerce.org/spree-commerce-version-comparison-community-edition-vs-enterprise-edition/).

## Features

- Support for quick checkout using Apple Pay, Google Pay, Stripe Link
- Support for 3D Secure and other security standards
- Support for off-session payments
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

## What's new?

### Installment (BNPL) payments indicator on PDP (Product Detail Page)

![Spree_x_Stripe_-_BNPL_Installment_payments_Product_Card_PDP_Product_Detail_Page](https://vendo-production-res.cloudinary.com/image/upload/w_2000/q_auto/v1742983146/docs/github/Spree_x_Stripe_-_BNPL_Installment_payments_Product_Card_PDP_Product_Detail_Page_amhfkw.jpg)

### Quick payment options on the cart (Apple Pay, Google Pay, Link)

![Apple_Pay_Google_Pay_Link_-_Quick_payment_options_on_the_cart](https://vendo-production-res.cloudinary.com/image/upload/w_2000/q_auto/v1742930027/docs/github/Spree_x_Stripe_-_Apple_Pay_Google_Pay_Link_-_Quick_payment_options_on_the_cart_aw45x9.jpg)

### Quick payments bypassing checkout 1st step (Apple Pay, Google Pay, Link)

![Apple_Pay_Google_Pay_Link_-_Quick_payments_bypassing_checkout](https://vendo-production-res.cloudinary.com/image/upload/w_2000/q_auto/v1742930027/docs/github/Spree_x_Stripe_-_Apple_Pay_Google_Pay_Link_-_Quick_payments_bypassing_checkout_on_Cart_n6gbh6.jpg)

### Various payment options on the payment step (cards, BNPL, Apple Pay, Google Pay, Link)

![Quick payments bypassing checkout 1st step (Apple Pay, Google_Pay, Link)](https://vendo-production-res.cloudinary.com/image/upload/w_2000/q_auto/v1742930027/docs/github/Spree_x_Stripe_-_Apple_Pay_Google_Pay_Link_-_Checkout_payment_step_rxxnr9.jpg)

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

  This Stripe integration is also bundled in the [Spree Starter](https://github.com/spree/spree_starter/) for your development convenience.

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

Copyright (c) 2026 [Vendo Connect Inc.](https://getvendo.com), released under [MIT](https://github.com/spree/spree_stripe/blob/main/LICENSE).

## Looking for a Stripe Connect integration for Spree?

Spree Commerce [Enterprise Edition](https://spreecommerce.org/spree-commerce-version-comparison-community-edition-vs-enterprise-edition/) comes with a fully automated Stripe Connect integration for a [multi-vendor marketplace use case](https://spreecommerce.org/marketplace-ecommerce/):

- Automated split payments between marketplace and vendors
- Support for multiple payment methods including cards and digital wallets
- Configurable marketplace fees and commission structures
- Automated payouts to vendors
- Comprehensive transaction reporting
- Built-in fraud prevention tools

Feel free to [reach out](https://spreecommerce.org/get-started/) to learn more.
