# Spree Commerce — Stripe App

This directory contains the Stripe App for Spree Commerce. The app generates a Restricted API Key (RAK) with scoped permissions that users paste into Spree Admin, replacing the need for full secret keys.

## Setup

Instalation guide: https://docs.stripe.com/stripe-apps/plugins/rak

## Permissions

The app requests the following permissions (configured in `stripe-app.json`):

- `payment_intent_write` / `payment_intent_read` — payment processing
- `payment_method_write` / `payment_method_read` — saved payment sources
- `customer_write` / `customer_read` — Stripe customer profiles
- `charge_write` / `charge_read` — refunds and charge details
- `checkout_session_write` / `checkout_session_read` — Stripe-hosted checkout
- `tax_calculations_and_transactions_write` / `tax_calculations_and_transactions_read` — Stripe Tax
- `connected_account_read` — multi-vendor support

## Settings Page

The settings UI is in `src/views/AppSettings.tsx`. It links to the Spree Stripe setup guide:

```
https://spreecommerce.org/docs/integrations/payments/stripe
```

## Preview and Publish

- Preview locally: `stripe apps start`
- Upload for review: `stripe apps upload`, then submit in Stripe Dashboard
