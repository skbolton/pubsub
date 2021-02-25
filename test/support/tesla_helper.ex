defmodule GenesisPubSub.Support.TeslaHelper do
  def response(args) do
    {:ok,
     %Tesla.Env{
       __client__: Keyword.get(args, :tesla_client, %Tesla.Client{}),
       status: Keyword.get(args, :status),
       body: Keyword.get(args, :body),
       method: Keyword.get(args, :method, :get),
       url: Keyword.get(args, :url, ""),
       headers: Keyword.get(args, :headers, [])
     }}
  end
end
