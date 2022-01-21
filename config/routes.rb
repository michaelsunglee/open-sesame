Rails.application.routes.draw do
  root :to => 'home#index'
  get '/wallets/validate', :to => 'wallets#validate'
  get '/wallets/verify_signature', :to => 'wallets#verify_signature'
  get '/products', :to => 'products#index'
  mount ShopifyApp::Engine, at: '/'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
