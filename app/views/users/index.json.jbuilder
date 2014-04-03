json.array!(@users) do |user|
  json.extract! user, :id, :name, :password, :email, :btc_address, :is_anonymous, :is_admin
  json.url user_url(user, format: :json)
end
