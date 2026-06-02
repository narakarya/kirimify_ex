defmodule Kirimify.Webhook do
  @moduledoc """
  Verifies inbound Kirimify webhook signatures.

  Kirimify signs each delivery with an HMAC-SHA256 of the **raw request body**
  using the webhook secret (shown only once, at webhook creation). The hex
  digest is sent in the `x-wa-signature` header as `sha256=<hex>`.
  """

  @signature_prefix "sha256="

  @doc """
  Verifies `signature_header` against `raw_body` using `secret`.

  `signature_header` may be the full header value (`"sha256=abc..."`) or the
  bare hex digest. Returns `:ok` or `{:error, :invalid_signature}`.
  Comparison is constant-time.
  """
  @spec verify(binary(), binary() | nil, binary()) :: :ok | {:error, :invalid_signature}
  def verify(raw_body, signature_header, secret)
      when is_binary(raw_body) and is_binary(secret) do
    given = strip_prefix(signature_header)
    expected = sign(raw_body, secret)

    if is_binary(given) and Plug.Crypto.secure_compare(expected, given) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  def verify(_raw_body, _signature_header, _secret), do: {:error, :invalid_signature}

  @doc "Computes the lowercase hex HMAC-SHA256 digest for `raw_body`."
  @spec sign(binary(), binary()) :: String.t()
  def sign(raw_body, secret) do
    :crypto.mac(:hmac, :sha256, secret, raw_body) |> Base.encode16(case: :lower)
  end

  defp strip_prefix(nil), do: nil
  defp strip_prefix(header), do: String.replace_prefix(header, @signature_prefix, "")
end
