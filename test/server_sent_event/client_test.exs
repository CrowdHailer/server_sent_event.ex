support_dir = Path.join(__DIR__, "client_test")

Code.require_file("auto_connect.ex", support_dir)
Code.require_file("manual_connect.ex", support_dir)
Code.require_file("auto_stop.ex", support_dir)
Code.require_file("hang_forever.ex", support_dir)

defmodule ServerSentEvent.ClientTest do
  use ExUnit.Case, async: true

  alias __MODULE__.AutoConnect
  alias __MODULE__.ManualConnect
  alias __MODULE__.AutoStop
  alias __MODULE__.HangForever

  {head, :chunked} =
    Raxx.HTTP1.serialize_response(
      Raxx.response(:ok)
      |> Raxx.set_header("content-type", "text/event-stream")
      |> Raxx.set_body(true)
    )

  @first_response head
  @event Raxx.HTTP1.serialize_chunk(ServerSentEvent.serialize("first"))

  test "Each server sent event is processed as it is received" do
    {port, listen_socket} = listen()
    {:ok, _client} = AutoConnect.start_link(port)

    {:ok, socket} = accept(listen_socket)
    {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
    assert String.contains?(first_request, "accept: text/event-stream")
    assert String.contains?(first_request, "\r\n\r\n")

    :ok = :gen_tcp.send(socket, [@first_response, @event])
    assert_receive {:connect, response = %Raxx.Response{}}, 5_000
    assert response.status == 200
    assert Raxx.get_header(response, "content-type") == "text/event-stream"

    assert_receive %ServerSentEvent{lines: ["first"]}, 5_000

    :ok = :gen_tcp.send(socket, Raxx.HTTP1.serialize_chunk(ServerSentEvent.serialize("second")))
    assert_receive %ServerSentEvent{lines: ["second"]}, 5_000
  end

  test "connection can be delayed at start up, and manual started" do
    {port, listen_socket} = listen()
    {:ok, client} = ManualConnect.start_link(port)

    {:error, :timeout} = accept(listen_socket)
    :ok = ManualConnect.connect(client)
    {:ok, socket} = accept(listen_socket)
    {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
    assert String.contains?(first_request, "accept: text/event-stream")
    assert String.contains?(first_request, "\r\n\r\n")

    :ok = :gen_tcp.send(socket, @first_response)
    assert_receive {:connect, _response}, 5_000
  end

  test "connection can be retried after failure to connect" do
    {port, listen_socket} = listen()
    {:ok, _client} = AutoConnect.start_link(port)

    assert_receive {:failure, :timeout}, 5_000

    # For some reason this catches the socket from the first connection attempt
    {:ok, _} = accept(listen_socket)
    {:ok, socket} = accept(listen_socket)
    {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
    assert String.contains?(first_request, "accept: text/event-stream")
    assert String.contains?(first_request, "\r\n\r\n")

    :ok = :gen_tcp.send(socket, @first_response)
    assert_receive {:connect, _response}, 5_000
  end

  test "connection can be retried after failure to receive data" do
    {port, listen_socket} = listen()
    {:ok, _client} = AutoConnect.start_link(port)

    {:ok, _socket} = accept(listen_socket)
    assert_receive {:failure, :timeout}, 5_000

    {:ok, socket} = accept(listen_socket)
    {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
    assert String.contains?(first_request, "accept: text/event-stream")
    assert String.contains?(first_request, "\r\n\r\n")

    :ok = :gen_tcp.send(socket, @first_response)
    assert_receive {:connect, _response}, 5_000
  end

  test "connection can stay unconnected after failure to connect" do
    {port, listen_socket} = listen()
    {:ok, client} = ManualConnect.start_link(port)
    :ok = ManualConnect.connect(client)

    assert_receive {:failure, :timeout}, 5_000

    # For some reason this catches the socket from the first connection attempt
    {:ok, _} = accept(listen_socket)
    {:error, :timeout} = accept(listen_socket)
  end

  test "client can be stopped on failure" do
    {port, _listen_socket} = listen()
    {:ok, client} = AutoStop.start_link(port)
    monitor = Process.monitor(client)

    assert_receive {:failure, :timeout}, 5_000
    assert_receive {:DOWN, ^monitor, :process, ^client, :normal}, 5_000
  end

  test "connection can be retried after disconnect" do
    {port, listen_socket} = listen()
    {:ok, _client} = AutoConnect.start_link(port)

    {:ok, socket} = accept(listen_socket)
    {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
    assert String.contains?(first_request, "accept: text/event-stream")
    assert String.contains?(first_request, "\r\n\r\n")

    :ok = :gen_tcp.send(socket, @first_response)
    assert_receive {:connect, _response}, 5_000

    :ok = :gen_tcp.close(socket)
    assert_receive {:disconnect, {:ok, :closed}}, 5_000

    {:ok, socket} = accept(listen_socket)
    {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
    assert String.contains?(first_request, "accept: text/event-stream")
    assert String.contains?(first_request, "\r\n\r\n")
  end

  test "connection can stay unconnected after disconnect" do
    {port, listen_socket} = listen()
    {:ok, client} = ManualConnect.start_link(port)
    :ok = ManualConnect.connect(client)

    {:ok, socket} = accept(listen_socket)
    {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
    assert String.contains?(first_request, "accept: text/event-stream")
    assert String.contains?(first_request, "\r\n\r\n")

    :ok = :gen_tcp.send(socket, @first_response)
    assert_receive {:connect, _response}, 5_000

    :ok = :gen_tcp.close(socket)
    assert_receive {:disconnect, {:ok, :closed}}, 5_000

    {:error, :timeout} = accept(listen_socket)
  end

  test "client can be stopped on disconnect" do
    {port, listen_socket} = listen()
    {:ok, client} = AutoStop.start_link(port)
    monitor = Process.monitor(client)

    {:ok, socket} = accept(listen_socket)
    {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
    assert String.contains?(first_request, "accept: text/event-stream")
    assert String.contains?(first_request, "\r\n\r\n")
    :ok = :gen_tcp.send(socket, @first_response)
    assert_receive {:connect, _response}, 5_000

    :ok = :gen_tcp.close(socket)
    assert_receive {:disconnect, {:ok, :closed}}, 5_000
    assert_receive {:DOWN, ^monitor, :process, ^client, :normal}, 5_000
  end

  test "client can be stopped by external message" do
    {port, listen_socket} = listen()
    {:ok, client} = AutoConnect.start_link(port)
    {:ok, socket} = accept(listen_socket)
    {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
    assert String.contains?(first_request, "accept: text/event-stream")
    assert String.contains?(first_request, "\r\n\r\n")
    :ok = :gen_tcp.send(socket, @first_response)
    assert_receive {:connect, _response}, 5_000
    monitor = Process.monitor(client)
    send(client, :stop)
    assert_receive {:DOWN, ^monitor, :process, ^client, :normal}, 5_000
  end

  test "content-length zero is a bad response" do
    {port, listen_socket} = listen()
    {:ok, _client} = AutoConnect.start_link(port)

    {:ok, socket} = accept(listen_socket)
    {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
    assert String.contains?(first_request, "accept: text/event-stream")
    assert String.contains?(first_request, "\r\n\r\n")

    {head, {:complete, body}} =
      Raxx.HTTP1.serialize_response(
        Raxx.response(:forbidden)
        |> Raxx.set_header("content-type", "text/plain")
        |> Raxx.set_body("Forbidden")
      )

    :ok = :gen_tcp.send(socket, [head, body])
    assert_receive {:failure, {:bad_response, %{status: 403}}}, 5_000
  end

  test "Only one packet is pulled from the socket" do
    {port, listen_socket} = listen()
    {:ok, client} = HangForever.start_link(port)

    {:ok, socket} = accept(listen_socket)
    {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
    assert String.contains?(first_request, "accept: text/event-stream")
    assert String.contains?(first_request, "\r\n\r\n")

    :ok = :gen_tcp.send(socket, @first_response)
    assert_receive {:connect, response = %Raxx.Response{}}, 5_000
    assert response.status == 200
    assert Raxx.get_header(response, "content-type") == "text/event-stream"
    :ok = :gen_tcp.send(socket, @event)
    Process.sleep(100)
    assert {:messages, []} = :erlang.process_info(client, :messages)
    :ok = :gen_tcp.send(socket, @event)
    Process.sleep(100)
    assert {:messages, [_one_event]} = :erlang.process_info(client, :messages)
    :ok = :gen_tcp.send(socket, @event)
    Process.sleep(1_000)
    assert {:messages, [_still_one_event]} = :erlang.process_info(client, :messages)
  end

  defp listen(port \\ 0) do
    {:ok, listen_socket} = :gen_tcp.listen(port, mode: :binary, packet: :raw, active: false)
    {:ok, port} = :inet.port(listen_socket)
    {port, listen_socket}
  end

  defp accept(listen_socket) do
    :gen_tcp.accept(listen_socket, 1_000)
  end
end
