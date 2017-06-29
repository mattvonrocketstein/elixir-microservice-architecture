require Logger

defmodule API.Sup do
  use Supervisor

  def start_link(_) do
    {:ok, _sup} = Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    processes = []
    {:ok, {{:one_for_one, 10, 10}, processes}}
  end
end

defmodule API.Handler do

  @headers  [ {"content-type", "application/json"} ]

  def init({:tcp, :http}, req, opts) do
    {:ok, body_unsupported} = JSX.encode(%{"error" => "unsupported method; please use GET or POST"})
    {:ok, body_accepted} = JSX.encode(%{"status" => "accepted"})
    {:ok, body_rejected} = JSX.encode(%{"error" => "missing data on post"})
    {:ok, body_niy} = JSX.encode(%{"status" => "niy"})
    {path, _} = :cowboy_req.path(req)
    {method, _} = :cowboy_req.method(req)
    Apex.ap "API #{method}: #{path}"
    method = to_string(method)
    {:ok, resp} = case method do
      "GET" ->
        Apex.ap "GET-dispatch"
        :cowboy_req.reply(200, @headers, body_niy, req)
      "POST" ->
        {:ok, body, _} = :cowboy_req.body(req)
        json = case JSX.decode(to_string(body)) do
          {:ok, json} ->
            Logger.info("decoded POST body successfully")
            json
          _ ->
            Logger.warn("cannot decode POST body!")
            %{}
        end
        try do
          %{"data" => data} = json
          Logger.info "POST is well-formed, accepting work `#{data}`"
          :cowboy_req.reply(200, @headers, body_accepted, req)
        rescue
          _err in MatchError ->
            Logger.warn "POST body is NOT well-formed; `data` field is missing"
            :cowboy_req.reply(400, @headers, body_rejected, req)
        end
      _ ->
        :cowboy_req.reply(400, @headers, body_unsupported, req)
    end
    {:ok, resp, opts}
  end

  def handle(req, state), do: {:ok, req, state}
  def terminate(_reason, _req, _state), do: :ok

end

defmodule API.Server do
  use Application

  def start(_type, _args) do
    start()
  end
  def start() do
    dispatch = :cowboy_router.compile([
      {:_, [
        {'/api/work/[...]', API.Handler, []},
        ]}
      ])
    IO.puts "Started listening on port 5983..."
    :cowboy.start_http :my_http_listener, 100, [{:port, 5983}], [{:env, [{:dispatch, dispatch}]}]
    API.Sup.start_link([])
  end

  def stop(_state) do
    :ok
  end
end
