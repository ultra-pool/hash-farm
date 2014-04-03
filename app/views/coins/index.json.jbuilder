json.array!(@coins) do |coin|
  json.extract! coin, :id, :name, :code, :second_per_block, :difficulty_retarget, :algo, :block_confirmation, :transaction_confirmation, :rpc_url, :bitcointalk_url, :website
  json.url coin_url(coin, format: :json)
end
