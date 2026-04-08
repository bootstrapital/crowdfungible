Rails.application.routes.draw do
  mount Rubot::Engine => "/rubot/admin"
  resources :trade_requests, only: %i[index new create show]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "trade_requests#new"
end
