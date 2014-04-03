json.array!(@shares) do |share|
  json.extract! share, :id, :worker, :solution, :difficulty, :our_result, :pool_result, :reason, :is_block
  json.url share_url(share, format: :json)
end
