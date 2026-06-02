defmodule Kirimify.CacheBodyReader do
  @moduledoc """
  A `Plug.Parsers` body reader that caches the raw request body in
  `conn.assigns.raw_body`, so `Kirimify.Plug` can verify the HMAC signature
  after the body has been parsed.

  Wire it into your endpoint's `Plug.Parsers`:

      plug Plug.Parsers,
        parsers: [:urlencoded, :json],
        pass: ["*/*"],
        body_reader: {Kirimify.CacheBodyReader, :read_body, []},
        json_decoder: Jason

  The raw body is accumulated across chunked reads. This runs for *every*
  request; the overhead is one extra list cons per chunk.
  """

  @spec read_body(Plug.Conn.t(), keyword()) ::
          {:ok, binary(), Plug.Conn.t()}
          | {:more, binary(), Plug.Conn.t()}
          | {:error, term()}
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} -> {:ok, body, cache(conn, body)}
      {:more, body, conn} -> {:more, body, cache(conn, body)}
      {:error, _} = error -> error
    end
  end

  defp cache(conn, chunk) do
    existing = conn.assigns[:raw_body] || []
    Plug.Conn.assign(conn, :raw_body, [existing, chunk])
  end
end
