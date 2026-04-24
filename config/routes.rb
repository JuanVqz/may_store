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

  resources :orders, only: [:index, :show] do
    member do
      patch :confirm
      patch :cancel
      get :bill
    end

    resources :payments, only: [:create]

    resources :line_items, only: [:new, :create, :destroy] do
      member do
        patch :ready
        patch :deliver
        patch :cancel
      end
    end
  end

  get "kitchen", to: "kitchen#index", as: :kitchen

  get "up" => "rails/health#show", as: :rails_health_check
end
