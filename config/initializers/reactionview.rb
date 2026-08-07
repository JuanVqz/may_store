# frozen_string_literal: true

# The reactionview gem is only bundled in :development and :test, so this
# initializer must do nothing when the constant is missing (production).
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
