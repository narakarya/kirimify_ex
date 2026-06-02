defmodule KirimifyTest do
  use ExUnit.Case, async: true

  # Stub the HTTP layer with Req's `:plug` option so no network is hit.
  defp client(stub) do
    Kirimify.Client.new(
      api_key: "wsk_test_123",
      base_url: "https://kirimify.test/api/v1",
      req_options: [plug: stub, retry: false]
    )
  end

  defp json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Jason.encode!(body))
  end

  test "send_text/4 maps 202 to {:ok, body} and sends the bearer token" do
    stub = fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/v1/messages/text"
      assert ["Bearer wsk_test_123"] = Plug.Conn.get_req_header(conn, "authorization")
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert %{"instance_id" => "i1", "to" => "628", "message" => "hi"} = Jason.decode!(raw)
      json(conn, 202, %{"id" => "m1", "status" => "queued"})
    end

    assert {:ok, %{"id" => "m1", "status" => "queued"}} =
             Kirimify.send_text("i1", "628", "hi", client: client(stub))
  end

  test "send_text/4 includes :quoted when given" do
    stub = fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert %{"quoted" => "q9"} = Jason.decode!(raw)
      json(conn, 202, %{"id" => "m2"})
    end

    assert {:ok, _} = Kirimify.send_text("i1", "628", "hi", quoted: "q9", client: client(stub))
  end

  test "non-2xx maps to {:error, %Kirimify.Error{}}" do
    stub = fn conn -> json(conn, 429, %{"error" => "Monthly message limit reached"}) end

    assert {:error, %Kirimify.Error{status: 429} = err} =
             Kirimify.send_text("i1", "628", "hi", client: client(stub))

    assert err.message =~ "Monthly message limit reached"
  end

  test "204 maps to {:ok, nil}" do
    stub = fn conn -> Plug.Conn.send_resp(conn, 204, "") end
    assert {:ok, nil} = Kirimify.instance("i1", client: client(stub))
  end

  test "messages/2 forwards query params" do
    stub = fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["instance_id"] == "i1"
      assert conn.query_params["limit"] == "10"
      json(conn, 200, [])
    end

    assert {:ok, []} =
             Kirimify.messages(%{instance_id: "i1", limit: 10}, client: client(stub))
  end
end
