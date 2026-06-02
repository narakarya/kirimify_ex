# Kirimify (Elixir)

Elixir client + webhook verifier for the [Kirimify](https://kirimify.narakarya.test) WhatsApp API.

Internal library — distributed via Git, not Hex.

## Install

```elixir
# mix.exs
def deps do
  [
    {:kirimify, github: "narakarya/kirimify_ex", tag: "v0.1.0"}
  ]
end
```

## Configure

```elixir
# config/runtime.exs
config :kirimify,
  api_key: System.get_env("KIRIMIFY_KEY"),
  base_url: "https://kirimify.narakarya.test/api/v1"
```

## Sending

Sends are **asynchronous** — `send_text/4` returns `202` with `status: "queued"`.
The final `sent`/`delivered`/`read`/`failed` status arrives via webhook.

```elixir
{:ok, %{"id" => id, "status" => "queued"}} =
  Kirimify.send_text(instance_id, "628123456789", "Halo!")

Kirimify.send_text(instance_id, "628...", "balasan", quoted: original_message_id)

Kirimify.send_media(instance_id, "628...", :image, "https://.../foto.jpg", caption: "Resep")

{:ok, account} = Kirimify.account()
{:ok, list}    = Kirimify.instances()
{:ok, msgs}    = Kirimify.messages(%{instance_id: instance_id, limit: 50})
```

Non-2xx responses return `{:error, %Kirimify.Error{status:, body:, message:}}`;
transport errors return `{:error, exception}`.

### Per-tenant clients

```elixir
client = Kirimify.Client.new(api_key: "wsk_live_...")
Kirimify.account(client: client)
```

## Receiving webhooks (delivery status, inbound messages)

Register a webhook in the Kirimify dashboard (or via the API) subscribed to
`message.status` (and/or `message.received`, `instance.connected`,
`instance.disconnected`). Copy the **secret** shown once on creation.

Signature verification needs the **raw** request body, so install the body
reader in your endpoint's `Plug.Parsers`:

```elixir
# lib/my_app_web/endpoint.ex
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  body_reader: {Kirimify.CacheBodyReader, :read_body, []},
  json_decoder: Jason
```

Forward to `Kirimify.Plug` from your router and implement a handler:

```elixir
# router.ex
forward "/webhooks/kirimify", Kirimify.Plug,
  handler: MyApp.KirimifyHandler,
  secret: {System, :fetch_env!, ["KIRIMIFY_WEBHOOK_SECRET"]}
```

```elixir
defmodule MyApp.KirimifyHandler do
  @behaviour Kirimify.WebhookHandler

  @impl true
  def handle_event("message.status", %{"id" => id, "status" => status}, _payload) do
    # `id` matches the id returned by Kirimify.send_text/4
    MyApp.Messaging.update_delivery_status(id, status)
  end

  def handle_event(_event, _data, _payload), do: :ok
end
```

`Kirimify.Plug` verifies the `x-wa-signature` HMAC-SHA256 header. Valid → `200`
+ handler called. Invalid → `401`, handler never runs. The handler's return
value is ignored, so enqueue heavy work rather than doing it inline.

### Webhook payload

```json
{
  "event": "message.status",
  "tenant_id": "uuid",
  "timestamp": 1717200000,
  "data": { "id": "<your message id>", "external_id": "...", "to": "628...", "status": "delivered" }
}
```

## Test

```sh
mix test
```

## License

MIT © Narakarya — see [LICENSE](LICENSE).
