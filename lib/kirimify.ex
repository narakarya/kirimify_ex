defmodule Kirimify do
  @moduledoc """
  Client for the [Kirimify](https://kirimify.narakarya.test) WhatsApp API.

  ## Configuration

      config :kirimify,
        api_key: System.get_env("KIRIMIFY_KEY"),
        base_url: "https://kirimify.narakarya.test/api/v1"

  ## Sending

      {:ok, %{"id" => id, "status" => "queued"}} =
        Kirimify.send_text(instance_id, "628123456789", "Halo!")

  Sends are **asynchronous**: `send_text/4` returns a `202` with `status:
  "queued"`. The final `sent` / `delivered` / `read` / `failed` status arrives
  via a `message.status` webhook — see `Kirimify.Plug`.

  ## Per-tenant clients

  Functions read config from the application environment by default. Pass an
  explicit client to override (e.g. multi-tenant):

      client = Kirimify.Client.new(api_key: "wsk_live_...")
      Kirimify.account(client: client)
  """

  alias Kirimify.{Client, Error}

  @type result :: {:ok, map() | nil} | {:error, Error.t() | Exception.t()}
  @type opts :: [client: Client.t()]

  # ── Account ──────────────────────────────────────────────────────────────

  @doc "Returns the authenticated tenant: plan, usage, limits."
  @spec account(opts()) :: result()
  def account(opts \\ []), do: get(opts, "/account")

  # ── Instances ───────────────────────────────────────────────────────────

  @doc "Lists all WhatsApp instances for the tenant."
  @spec instances(opts()) :: result()
  def instances(opts \\ []), do: get(opts, "/instances")

  @doc "Fetches a single instance by id."
  @spec instance(String.t(), opts()) :: result()
  def instance(id, opts \\ []), do: get(opts, "/instances/#{id}")

  @doc "Returns the QR payload (or connection status) for pairing an instance."
  @spec instance_qr(String.t(), opts()) :: result()
  def instance_qr(id, opts \\ []), do: get(opts, "/instances/#{id}/qr")

  # ── Messages ────────────────────────────────────────────────────────────

  @doc """
  Lists messages. Supported `params`: `:instance_id`, `:direction`, `:limit`.
  """
  @spec messages(map() | keyword(), opts()) :: result()
  def messages(params \\ %{}, opts \\ []) do
    opts
    |> Client.resolve()
    |> Client.req()
    |> Req.get(url: "/messages", params: Enum.into(params, []))
    |> handle()
  end

  @doc """
  Queues a text message for delivery. Returns `202` with `status: "queued"`.

  Options:
    * `:quoted` — id of a message to quote/reply to
    * `:client` — explicit `Kirimify.Client`
  """
  @spec send_text(String.t(), String.t(), String.t(), keyword()) :: result()
  def send_text(instance_id, to, message, opts \\ []) do
    body =
      %{instance_id: instance_id, to: to, message: message}
      |> put_optional(:quoted, opts[:quoted])

    post(opts, "/messages/text", body)
  end

  @doc """
  Sends a media message. `type` is one of `:image`, `:video`, `:audio`,
  `:document` (atoms or strings accepted).

  Options: `:caption`, `:filename`, `:mimetype`, `:client`.
  """
  @spec send_media(String.t(), String.t(), atom() | String.t(), String.t(), keyword()) :: result()
  def send_media(instance_id, to, type, url, opts \\ []) do
    body =
      %{instance_id: instance_id, to: to, type: to_string(type), url: url}
      |> put_optional(:caption, opts[:caption])
      |> put_optional(:filename, opts[:filename])
      |> put_optional(:mimetype, opts[:mimetype])

    post(opts, "/messages/media", body)
  end

  # ── HTTP plumbing ─────────────────────────────────────────────────────────

  defp get(opts, path) do
    opts |> Client.resolve() |> Client.req() |> Req.get(url: path) |> handle()
  end

  defp post(opts, path, body) do
    opts |> Client.resolve() |> Client.req() |> Req.post(url: path, json: body) |> handle()
  end

  defp put_optional(map, _key, nil), do: map
  defp put_optional(map, key, value), do: Map.put(map, key, value)

  # 204 No Content -> {:ok, nil}; other 2xx -> {:ok, body}; else -> {:error, _}.
  defp handle({:ok, %Req.Response{status: 204}}), do: {:ok, nil}

  defp handle({:ok, %Req.Response{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  defp handle({:ok, %Req.Response{status: status, body: body}}),
    do: {:error, Error.exception(status: status, body: body)}

  defp handle({:error, exception}), do: {:error, exception}
end
