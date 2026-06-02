defmodule Kirimify.Plug do
  @moduledoc """
  A Plug that verifies an inbound Kirimify webhook and dispatches it to your
  handler. On a valid signature it responds `200 ok` and calls
  `handler.handle_event/3`; on an invalid signature it responds `401` and never
  calls the handler.

  ## Options

    * `:handler` (required) — a module implementing `Kirimify.WebhookHandler`
    * `:secret` (required) — the webhook secret, as one of:
      * a binary
      * a 0-arity function returning the binary
      * an `{module, function, args}` tuple returning the binary

  ## Raw body

  Signature verification needs the **raw** request body. In a Phoenix endpoint
  that runs `Plug.Parsers`, install `Kirimify.CacheBodyReader` so the raw body
  is stashed in `conn.assigns.raw_body`:

      plug Plug.Parsers,
        parsers: [:urlencoded, :json],
        body_reader: {Kirimify.CacheBodyReader, :read_body, []},
        json_decoder: Jason

  Then forward to this plug from your router:

      forward "/webhooks/kirimify", Kirimify.Plug,
        handler: MyApp.KirimifyHandler,
        secret: {System, :fetch_env!, ["KIRIMIFY_WEBHOOK_SECRET"]}

  If `conn.assigns.raw_body` is absent (e.g. the plug runs before parsers), it
  reads the body directly.
  """

  @behaviour Plug
  import Plug.Conn

  alias Kirimify.Webhook

  @impl true
  def init(opts) do
    %{
      handler: Keyword.fetch!(opts, :handler),
      secret: Keyword.fetch!(opts, :secret)
    }
  end

  @impl true
  def call(conn, %{handler: handler, secret: secret}) do
    {raw_body, conn} = raw_body(conn)
    signature = conn |> get_req_header("x-wa-signature") |> List.first()

    case Webhook.verify(raw_body, signature, resolve_secret(secret)) do
      :ok ->
        payload = Jason.decode!(raw_body)
        event = payload["event"] || conn |> get_req_header("x-wa-event") |> List.first()
        _ = handler.handle_event(event, payload["data"], payload)

        conn |> send_resp(200, "ok") |> halt()

      {:error, :invalid_signature} ->
        conn |> send_resp(401, "invalid signature") |> halt()
    end
  end

  defp raw_body(conn) do
    case conn.assigns[:raw_body] do
      nil ->
        {:ok, body, conn} = read_body(conn)
        {body, conn}

      cached ->
        {IO.iodata_to_binary(cached), conn}
    end
  end

  defp resolve_secret(secret) when is_binary(secret), do: secret
  defp resolve_secret(fun) when is_function(fun, 0), do: fun.()
  defp resolve_secret({m, f, a}), do: apply(m, f, a)
end
