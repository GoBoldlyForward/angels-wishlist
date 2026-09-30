namespace :admin do
  root "dashboard#index"

  # Families
  resources :households, only: %i[index show new create edit update] do
    member do
      patch :verify
      patch :hold
      patch :archive
    end
  end
  resources :wishlists, only: %i[index show] do
    member do
      patch :approve
      patch :return_to_caregiver
      patch :withdraw
    end
  end
  resources :line_items, only: %i[index show edit update] do
    member do
      patch :approve
      patch :withdraw
    end
  end
  resource :love_box, only: :show

  # Inbox
  resource :inbox, only: :show
  resources :donor_notes, only: [] do
    member do
      patch :approve
      patch :discard
    end
  end
  resources :versions, only: :index

  # Funding
  resources :donors, only: %i[index show]
  resources :donations, only: %i[index show new create] do
    member do
      patch :refund
      post :resend_receipt
    end
  end
  resources :payouts, only: %i[index show] do
    collection { post :build }
    member do
      patch :send_funds
      patch :mark_delivered
    end
  end
  resource :impact_statement, only: %i[new create]
  resource :chapter_funds, only: :show do
    post :release
  end

  # Setup
  resources :events, except: :destroy
  resources :categories, except: :show
  resources :catalog_items, except: :show
  resources :organizations, except: :destroy
  resources :organizers, only: %i[index new create destroy]
  resource :stripe_connection, only: %i[show create]
end
