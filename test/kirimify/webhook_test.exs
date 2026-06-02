defmodule Kirimify.WebhookTest do
  use ExUnit.Case, async: true

  alias Kirimify.Webhook

  @secret "topsecret"
  @body ~s({"event":"message.status","data":{"id":"abc","status":"delivered"}})

  test "sign/2 matches the server-side HMAC-SHA256 hex digest" do
    expected =
      :crypto.mac(:hmac, :sha256, @secret, @body) |> Base.encode16(case: :lower)

    assert Webhook.sign(@body, @secret) == expected
  end

  test "verify/3 accepts a valid sha256-prefixed signature" do
    sig = "sha256=" <> Webhook.sign(@body, @secret)
    assert Webhook.verify(@body, sig, @secret) == :ok
  end

  test "verify/3 accepts a bare hex digest (no prefix)" do
    assert Webhook.verify(@body, Webhook.sign(@body, @secret), @secret) == :ok
  end

  test "verify/3 rejects a tampered body" do
    sig = "sha256=" <> Webhook.sign(@body, @secret)
    assert Webhook.verify(@body <> "x", sig, @secret) == {:error, :invalid_signature}
  end

  test "verify/3 rejects a wrong secret" do
    sig = "sha256=" <> Webhook.sign(@body, @secret)
    assert Webhook.verify(@body, sig, "wrong") == {:error, :invalid_signature}
  end

  test "verify/3 rejects a nil signature" do
    assert Webhook.verify(@body, nil, @secret) == {:error, :invalid_signature}
  end
end
