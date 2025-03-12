pin 'application-spree-stripe', to: 'spree_stripe/application.js', preload: false

pin '@stripe/stripe-js/pure', to: '@stripe--stripe-js--dist--pure.esm.js.js' # @1.46.0

pin_all_from SpreeStripe::Engine.root.join('app/javascript/spree_stripe/controllers'),
             under: 'spree_stripe/controllers',
             to: 'spree_stripe/controllers',
             preload: 'application-spree-stripe'
