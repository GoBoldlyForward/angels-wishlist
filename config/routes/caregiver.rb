namespace :caregiver do
  root "dashboard#index"

  scope path: "intake", as: :intake do
    resource :home, only: %i[show create update]
    resource :children, only: %i[show update]
    resource :love_box, only: %i[show update]
    resources :lists, only: %i[index show] do
      collection { patch :finish }
      resources :gifts, only: %i[create destroy]
      resource :submission, only: :create, controller: "list_submissions"
    end
    resource :payout, only: %i[show update]
    resource :stripe_connection, only: :create
    resource :review, only: :show
    resource :submission, only: %i[show create]
  end
end
