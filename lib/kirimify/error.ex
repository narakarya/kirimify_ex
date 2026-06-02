defmodule Kirimify.Error do
  @moduledoc "Represents a non-2xx response from the Kirimify API."

  defexception [:status, :body, :message]

  @type t :: %__MODULE__{
          status: pos_integer() | nil,
          body: term(),
          message: String.t()
        }

  @impl true
  def exception(opts) do
    status = Keyword.get(opts, :status)
    body = Keyword.get(opts, :body)
    %__MODULE__{status: status, body: body, message: build_message(status, body)}
  end

  defp build_message(status, %{"error" => error}), do: "Kirimify API #{status}: #{error}"

  defp build_message(status, %{"errors" => errors}),
    do: "Kirimify API #{status}: #{inspect(errors)}"

  defp build_message(status, _body), do: "Kirimify API returned status #{status}"
end
