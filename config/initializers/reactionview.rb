# frozen_string_literal: true

# The gem is in the :development, :test group, so `Bundler.require(*Rails.groups)`
# never requires it in production and this constant is undefined there. Note the
# gem is still *installed* in the production image: Dockerfile sets
# BUNDLE_WITHOUT="development" only, which leaves :test in. So do not read this
# guard as "the gem is absent" — it means "the gem was not required". Anything
# that adds an explicit `require "reactionview"` would route every production
# template through Herb::Engine with validation_mode :overlay.
return unless defined?(ReActionView)

ReActionView.configure do |config|
  # Intercept .html.erb templates and process them with `Herb::Engine` so HTML
  # validation runs while rendering. Tests raise on invalid markup, development
  # shows the overlay instead.
  config.intercept_erb = true

  # Enable debug mode in development (adds debug attributes to HTML)
  config.debug_mode = Rails.env.development?

  # Validation mode (:raise, :overlay, or :none) — defaults to :raise in test, :overlay otherwise
  # config.validation_mode = :overlay

  # Add custom transform visitors to process templates before compilation
  # config.transform_visitors = [
  #   Herb::Visitor::new
  # ]
end
