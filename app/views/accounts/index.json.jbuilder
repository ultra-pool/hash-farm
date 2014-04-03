json.array!(@accounts) do |account|
  json.extract! account, :id, :coin_id, :address, :label
  json.url account_url(account, format: :json)
end
