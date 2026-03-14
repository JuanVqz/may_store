Rails.application.routes.draw do
  # Auth
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Tables
  resources :tables, only: [:index] do
    # Create new order for a table
    resources :orders, only: [:create], controller: "orders", as: :orders
  end

  # Orders
  resources :orders, only: [:show] do
    member do
      patch :confirm
      patch :cancel
    end

    # Line items within an order
    resources :line_items, only: [:new, :create, :destroy] do
      member do
        patch :ready
        patch :deliver
        patch :cancel
      end
    end
  end

  # Kitchen (placeholder)
  get "kitchen", to: "kitchen#index", as: :kitchen

  # Admin (placeholder)
  get "admin", to: "admin/dashboard#index", as: :admin_dashboard

  get "up" => "rails/health#show", as: :rails_health_check

  root "sessions#new"
end
