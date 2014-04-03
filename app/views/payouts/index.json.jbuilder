json.array!(@payouts) do |payout|
  json.extract! payout, :id, :transaction_id, :our_fees, :users_amount
  json.url payout_url(payout, format: :json)
end
