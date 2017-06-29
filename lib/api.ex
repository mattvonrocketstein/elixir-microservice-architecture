require Logger
require IEx

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

defmodule API.Response do

  @headers  [ {"content-type", "application/json"} ]

  def unsupported(req) do
    {:ok, body_unsupported} = JSX.encode(%{"error" => "unsupported method; please use GET or POST"})
    :cowboy_req.reply(400, @headers, body_unsupported, req)
  end

  def accepted(req) do
    {:ok, body_accepted} = JSX.encode(%{"status" => "accepted"})
    :cowboy_req.reply(200, @headers, body_accepted, req)
  end
  def rejected(req, reason) do
    {:ok, body_rejected} = JSX.encode(%{"error" => reason})
    :cowboy_req.reply(400, @headers, body_rejected, req)
  end
  def retrieved(req) do
    {:ok, body_niy} = JSX.encode(%{"status" => "niy"})
    :cowboy_req.reply(200, @headers, body_niy, req)
  end

  def notfound(req) do
    {:ok, body} = JSX.encode(%{"status" => "404. not found!"})
    :cowboy_req.reply(404, @headers, body, req)
  end
end

defmodule API.Handler do
  @_handler_root "/api/work"
  def handler_root(), do: @_handler_root
  def decode_body(req) do
    {:ok, body, _} = :cowboy_req.body(req)
    json = case JSX.decode(to_string(body)) do
      {:ok, json} ->
        Logger.info("decoded POST body successfully")
        json
      _ ->
        Logger.warn("cannot decode POST body!")
        %{}
      end
  end
  def get_callback(path) do
    callback_id = String.slice(
      path,
      String.length(handler_root),
      String.length(path))
    if String.starts_with?(callback_id, "/") do
      callback_id = String.slice(callback_id, 1, String.length(callback_id))
    end
    if String.length(callback_id) > 0 do
      callback_id
    else
      nil
    end
  end
  def init({:tcp, :http}, req, opts) do
    {path, _} = :cowboy_req.path(req)
    {method, _} = :cowboy_req.method(req)
    Apex.ap "API #{method}: #{path}"
    method = to_string(method)
    {:ok, resp} = case method do
      "GET" ->
        pid = Process.whereis(Cluster)
        callback_id = get_callback(path)
        case callback_id do
          nil ->
            error = "No callback_id was given in GET request"
            Logger.warn error
            API.Response.rejected(req, error)
          _ ->
            Logger.info "Received callback_id `#{callback_id}`"
            callback_data = Redix.command(pid, ["GET", callback_id])
            case callback_data do
              {:ok, nil} ->
                Logger.warn "Data for callback `#{callback_id}` not found"
                API.Response.notfound(req)
              {:ok, _} ->
                Logger.info "Data for callback `#{callback_id}` was found"
                API.Response.retrieved(req)
            end
        end
      "POST" ->
        json = decode_body(req)
        try do
          %{"data" => data} = json
          Logger.info "POST is well-formed, accepting work `#{data}`"
          API.Response.accepted(req)
        rescue
          _err in MatchError ->
            error = "POST body is NOT well-formed; `data` field is missing"
            Logger.warn error
            API.Response.rejected(req, error)
        end
      _ ->
        API.Response.unsupported(req)
    end
    {:ok, resp, opts}
  end

  def handle(req, state), do: {:ok, req, state}
  def terminate(_reason, _req, _state), do: :ok

end

defmodule API.Server do
  use Application

  @api_port 5983

  def start(_type, _args), do: start()
  def stop(_state), do: :ok

  def start() do
    dispatch = :cowboy_router.compile([
      {:_, [
        {API.Handler.handler_root() <> "/[...]", API.Handler, []},
        ]}
      ])
    Apex.ap "Started listening on port #{@api_port}..."
    :cowboy.start_http :my_http_listener, 100, [{:port, @api_port}], [{:env, [{:dispatch, dispatch}]}]
    API.Sup.start_link([])
  end
end
