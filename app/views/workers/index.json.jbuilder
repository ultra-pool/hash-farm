json.array!(@workers) do |worker|
  json.extract! worker, :id, :user_id, :name, :is_anonymous
  json.url worker_url(worker, format: :json)
end
