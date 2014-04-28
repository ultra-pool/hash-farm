json.array!(@orders) do |order|
  json.extract! order, :id, :user_id, :algo, :url, :username, :password, :pay, :price, :limit, :hash_done, :complete, :running
  json.url order_url(order, format: :json)
end
