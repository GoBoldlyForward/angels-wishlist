# A partner's storefront lives at /with/<partner>, skinned throughout.
scope "(/with/:storefront)", module: "public" do
  root "home#index"

  resources :categories, only: :show do
    resource :funding, only: :create, module: :categories
  end
  resources :gifts, only: :show do
    resource :funding, only: %i[create destroy], module: :gifts
  end
  resources :children, only: :show do
    resource :funding, only: :create, module: :children
  end

  resource :cart, only: :show do
    resources :gifts, only: %i[create destroy], module: :carts
    resources :general_gifts, only: %i[create destroy], module: :carts
  end
  resource :checkout, only: %i[show create]
  resources :donations, only: :show, param: :uuid
end
