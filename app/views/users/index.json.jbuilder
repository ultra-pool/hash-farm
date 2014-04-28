json.array!(@users) do |user|
  json.extract! user, :id, :name, :password, :email, :payout_address, :wallet_address, :is_anonymous, :is_admin
  json.url user_url(user, format: :json)
end
