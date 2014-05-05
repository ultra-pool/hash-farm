HashFarm::Application.routes.draw do
  devise_for :users
  root to: 'pages#promo'
end