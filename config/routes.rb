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

    # ESC/POS byte streams, fetched by the print Stimulus controller and
    # forwarded to the thermal printer over WebUSB. Not HTML: see
    # docs/references/thermal-printing.md.
    resource :receipt, only: [:show]
    resource :kitchen_ticket, only: [:show]

    resources :payments, only: [:create]

    resources :line_items, only: [:new, :create, :update, :destroy] do
      member do
        patch :ready
        patch :deliver
        patch :cancel
      end
    end
  end

  get "kitchen", to: "kitchen#index", as: :kitchen

  namespace :admin do
    # The catalogue is set up once; the corte is opened every day, so it is what
    # an admin is almost always coming here for.
    root "cash_closings#index"
    resources :categories
    resources :components
    resources :products
    resources :spots
    resources :payment_methods

    resources :cash_closings, only: [:index, :show, :create, :update] do
      # The printed corte, as ESC/POS bytes. Same transport as the bills.
      resource :receipt, only: [:show], controller: "cash_closing_receipts"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
