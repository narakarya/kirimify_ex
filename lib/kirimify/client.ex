defmodule Kirimify.Client do
  @moduledoc """
  Holds the per-request configuration (API key + base URL) and builds the
  underlying `Req` request.

  A client can be built explicitly with `new/1` for multi-tenant use, or
  resolved from application config via `from_env/0`:

      config :kirimify,
        api_key: System.get_env("KIRIMIFY_KEY"),
        base_url: "https://kirimify.narakarya.test/api/v1"
  """

  @enforce_keys [:api_key, :base_url]
  defstruct [:api_key, :base_url, req_options: []]

  @type t :: %__MODULE__{
          api_key: String.t(),
          base_url: String.t(),
          req_options: keyword()
        }

  @default_base_url "https://kirimify.narakarya.test/api/v1"

  @doc """
  Builds a client from explicit options.

  Options:
    * `:api_key` (required) — the `wsk_live_...` token
    * `:base_url` — defaults to the production Kirimify API
    * `:req_options` — extra options merged into every `Req` request
      (e.g. `receive_timeout:`, `retry:`)
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    %__MODULE__{
      api_key: Keyword.fetch!(opts, :api_key),
      base_url: Keyword.get(opts, :base_url, @default_base_url),
      req_options: Keyword.get(opts, :req_options, [])
    }
  end

  @doc "Resolves a client from `:kirimify` application config."
  @spec from_env() :: t()
  def from_env do
    api_key =
      Application.get_env(:kirimify, :api_key) ||
        raise ArgumentError,
              "missing :api_key — set `config :kirimify, api_key: ...` or pass `client:`"

    new(
      api_key: api_key,
      base_url: Application.get_env(:kirimify, :base_url, @default_base_url),
      req_options: Application.get_env(:kirimify, :req_options, [])
    )
  end

  @doc false
  @spec resolve(keyword()) :: t()
  def resolve(opts) do
    case Keyword.get(opts, :client) do
      %__MODULE__{} = client -> client
      nil -> from_env()
    end
  end

  @doc false
  @spec req(t()) :: Req.Request.t()
  def req(%__MODULE__{} = client) do
    [
      base_url: client.base_url,
      auth: {:bearer, client.api_key},
      # No automatic retry: sends are non-idempotent (a retried POST /messages
      # would deliver a duplicate WhatsApp message). Opt in per-client via
      # `req_options: [retry: :transient]` for read-only calls if desired.
      retry: false
    ]
    |> Keyword.merge(client.req_options)
    |> Req.new()
  end
end
