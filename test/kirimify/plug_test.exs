defmodule Kirimify.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias Kirimify.Webhook

  @secret "plugsecret"

  defmodule EchoHandler do
    @behaviour Kirimify.WebhookHandler
    @impl true
    def handle_event(event, data, payload) do
      send(self(), {:handled, event, data, payload})
    end
  end

  defp opts, do: Kirimify.Plug.init(handler: EchoHandler, secret: @secret)

  defp request(body, signature) do
    conn(:post, "/webhooks/kirimify", body)
    |> put_req_header("content-type", "application/json")
    |> then(fn c -> if signature, do: put_req_header(c, "x-wa-signature", signature), else: c end)
  end

  test "valid signature -> 200 and handler invoked with decoded payload" do
    body = ~s({"event":"message.status","data":{"id":"m1","status":"sent"}})
    sig = "sha256=" <> Webhook.sign(body, @secret)

    conn = Kirimify.Plug.call(request(body, sig), opts())

    assert conn.status == 200
    assert conn.halted
    assert_received {:handled, "message.status", %{"id" => "m1", "status" => "sent"}, payload}
    assert payload["event"] == "message.status"
  end

  test "invalid signature -> 401 and handler NOT invoked" do
    body = ~s({"event":"message.status","data":{}})
    conn = Kirimify.Plug.call(request(body, "sha256=deadbeef"), opts())

    assert conn.status == 401
    assert conn.halted
    refute_received {:handled, _, _, _}
  end

  test "missing signature -> 401" do
    body = ~s({"event":"x","data":{}})
    conn = Kirimify.Plug.call(request(body, nil), opts())
    assert conn.status == 401
  end
end
