# A partner's storefront lives at /with/<partner>, skinned throughout.
scope "(/with/:storefront)", module: "public" do
  root "home#index"
end
