Rails.application.routes.draw do
  devise_for :users, skip: :registrations

  get "up" => "rails/health#show", as: :rails_health_check
  post "stripe/webhooks" => "stripe_webhooks#create"

  draw :admin
  draw :caregiver
  draw :public
end
