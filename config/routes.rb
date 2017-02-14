Coupons::Engine.routes.draw do
  get '/coupons/apply', to: 'coupons#apply', as: 'apply_coupon', format: 'json'
  patch '/coupons', to: 'coupons#batch'

  resources :coupons do
    get :remove, on: :member
    get :duplicate, on: :member
  end

  scope path: 'coupons', as: 'coupons' do
    resources(
      :weekly,
      controller: 'coupons',
      recurrence_type: 'Coupons::Models::CouponWeekly'
    )
  end
end
