defmodule Kirimify.WebhookHandler do
  @moduledoc """
  Behaviour for modules that handle verified Kirimify webhook events.

  `handle_event/3` receives the event name, the event's `data` map, and the
  full decoded payload (`%{"event", "tenant_id", "timestamp", "data"}`). The
  return value is ignored — `Kirimify.Plug` always replies `200` once the
  signature is valid, so heavy work should be enqueued, not done inline.

  Known events: `"message.status"`, `"message.received"`,
  `"instance.connected"`, `"instance.disconnected"`.

      defmodule MyApp.KirimifyHandler do
        @behaviour Kirimify.WebhookHandler

        @impl true
        def handle_event("message.status", %{"id" => id, "status" => status}, _payload) do
          MyApp.Messaging.update_delivery_status(id, status)
        end

        def handle_event(_event, _data, _payload), do: :ok
      end
  """

  @callback handle_event(event :: String.t() | nil, data :: map(), payload :: map()) :: any()
end
