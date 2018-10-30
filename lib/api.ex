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

  def accepted(req, callback_id, data) do
    {:ok, body_accepted} = JSX.encode(
      %{"status" => "accepted",
        "accepted_by" => Node.self(),
        "data" => data,
        "callback" => callback_id})
    :cowboy_req.reply(200, @headers, body_accepted, req)
  end

  def rejected(req, reason) do
    {:ok, body_rejected} = JSX.encode(%{"error" => reason})
    :cowboy_req.reply(400, @headers, body_rejected, req)
  end

  def retrieved(req, status) do
    {:ok, body} = JSX.encode(%{"status" => status})
    :cowboy_req.reply(200, @headers, body, req)
  end

  def notfound(req) do
    {:ok, body} = JSX.encode(%{"status" => "404. not found!"})
    :cowboy_req.reply(404, @headers, body, req)
  end
end

defmodule Callback do

  def write(callback_id, status, data) do
    callback_id = normalize(callback_id)
    # Logger.info("Writing status \"#{status}\" to key @ #{callback_id}")
    pid = Cluster.pid()
    # data_string = Poison.encode!(Map.put(data, :status, status))
    data_string = Poison.encode!(Map.put(data, "status", status))
    Functions.report("encoded data: " <> data_string)
    {:ok, _} = case status do
      "working" ->
        Redix.command(pid,
          [ "SET", callback_id, data_string])
      "worked" ->
        Redix.command(Cluster.pid(),
          [ "SETEX", callback_id, 10, data_string])
      "pending" ->
        Redix.command(Cluster.pid(),
          [ "SET", callback_id, data_string])
      _ ->
        raise ArgumentError, message: "bad status for callback write"
    end
  end

  def generate_id(data) do
    :crypto.hash(:md5, data) |> Base.encode16()
  end

  def normalize(callback_id) do
    if not String.starts_with?(callback_id, "_") do
      "_" <> callback_id
    else
      callback_id
    end
  end

  def get_data(callback_id) do
    {:ok, data} = Redix.command(
      Cluster.pid(),
      ["GET", normalize(callback_id)])
    if data do
      Poison.decode!(data)
    end
  end

  def from_path(path, handler_root) do
    callback_id = String.slice(
      path,
      String.length(handler_root),
      String.length(path))
    callback_id = if String.starts_with?(callback_id, "/") do
        String.slice(callback_id, 1, String.length(callback_id))
      else
        callback_id
      end
    if String.length(callback_id) > 0 do
      callback_id
    else
      nil
    end
  end
end

defmodule API.Handler do
  @_handler_root "/api/v1/work"

  def handler_root(), do: @_handler_root

  def decode_body(req) do
    {:ok, body, _} = :cowboy_req.body(req)
    case JSX.decode(to_string(body)) do
      {:ok, json} ->
        Logger.info("decoded POST body successfully")
        Functions.report(json)
        json
      _ ->
        Logger.warn("cannot decode POST body!")
        %{}
      end
  end


  def init({:tcp, :http}, req, opts) do
    {path, _} = :cowboy_req.path(req)
    {method, _} = :cowboy_req.method(req)
    Functions.report("API #{method}: #{path}")
    method = to_string(method)
    {:ok, resp} = case method do
      "GET" ->
        #pid = Process.whereis(Cluster)
        callback_id = Callback.from_path(path, handler_root())
        case callback_id do
          nil ->
            error = "No callback_id was given in GET request"
            Logger.warn error
            API.Response.rejected(req, error)
          _ ->
            Logger.info "Received callback_id `#{callback_id}`"
            callback_data = Callback.get_data(callback_id)
            case callback_data do
              nil ->
                Logger.warn "Data for callback `#{callback_id}` not found"
                API.Response.notfound(req)
              _ ->
                Logger.info "Data for callback `#{callback_id}` was found"
                API.Response.retrieved(req, callback_data)
            end
        end
      "POST" ->
        # json = decode_body(req)
        {:ok, body, _} = :cowboy_req.body(req)
        json = Poison.decode!(to_string(body))
        try do
          %{"data" => data} = json
          Logger.info "POST is well-formed, accepting work `#{data}`"
          callback_id = Callback.generate_id(data)
          {:ok, _} = Callback.write(callback_id, "pending", json)
          API.Response.accepted(req, callback_id, data)
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

  @api_port 80

  def start(_type, _args), do: start()

  def stop(_state), do: :ok

  def start() do
    dispatch = :cowboy_router.compile([
      {:_, [
        {API.Handler.handler_root() <> "/[...]", API.Handler, []},
        ]}
      ])
    Functions.report "Started listening on port #{@api_port}..."
    :cowboy.start_http :my_http_listener, 100, [{:port, @api_port}], [{:env, [{:dispatch, dispatch}]}]
    API.Sup.start_link([])
  end
end
