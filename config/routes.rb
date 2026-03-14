Rails.application.routes.draw do
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  root "home#index"

  resources :tables, only: [:index]

  resources :takeouts, only: [:index]

  resources :spots, only: [] do
    resources :orders, only: [:create]
  end

  resources :orders, only: [:show] do
    member do
      patch :confirm
      patch :cancel
    end

    resources :line_items, only: [:new, :create, :destroy] do
      member do
        patch :ready
        patch :deliver
        patch :cancel
      end
    end
  end

  get "kitchen", to: "kitchen#index", as: :kitchen

  get "admin", to: "admin/dashboard#index", as: :admin_dashboard

  get "up" => "rails/health#show", as: :rails_health_check
end
