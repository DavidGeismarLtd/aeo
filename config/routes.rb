Rails.application.routes.draw do
  # Devise routes with custom controllers
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions",
    passwords: "users/passwords",
    confirmations: "users/confirmations"
  }

  # Authenticated routes
  authenticated :user do
    # Workspace management
    resources :workspaces, only: [ :index, :new, :create, :show, :edit, :update ]

    # Workspace-scoped routes
    scope ":workspace_slug", as: :workspace do
      get "/", to: "dashboard#index", as: :dashboard
      resources :brands
      resources :settings, only: [ :index, :update ]
      resources :team_members, only: [ :index, :create, :destroy ]
    end

    # Authenticated root redirects to dashboard
    root "dashboard#index", as: :authenticated_root
  end

  # Public root
  root "pages#home"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
