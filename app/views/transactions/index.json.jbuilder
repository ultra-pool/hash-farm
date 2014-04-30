json.array!(@transactions) do |transaction|
  json.extract! transaction, :id, :raw, :txid, :ourid, :block
  json.url transaction_url(transaction, format: :json)
end
