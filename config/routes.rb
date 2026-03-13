Rails.application.routes.draw do
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Role-based landing pages (placeholder routes for now)
  get "tables", to: "tables#index", as: :tables
  get "kitchen", to: "kitchen#index", as: :kitchen
  get "admin", to: "admin/dashboard#index", as: :admin_dashboard

  get "up" => "rails/health#show", as: :rails_health_check

  root "sessions#new"
end
