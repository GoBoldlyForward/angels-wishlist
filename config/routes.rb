Rails.application.routes.draw do
  devise_for :users

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :admin do
    root "dashboard#index"
  end

  namespace :household do
    root "dashboard#index"
  end

  scope module: "public" do
    root "home#index"
  end
end
