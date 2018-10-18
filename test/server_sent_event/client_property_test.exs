defmodule ServerSentEvent.ClientPropertyTest do
  # use ExUnit.Case, async: true

  # alias ServerSentEvent.ClientTest.AutoConnect

  # {head, :chunked} =
  #   Raxx.HTTP1.serialize_response(
  #     Raxx.response(:ok)
  #     |> Raxx.set_header("content-type", "text/event-stream")
  #     |> Raxx.set_body(true)
  #   )

  # @first_response head
  # @event Raxx.HTTP1.serialize_chunk(ServerSentEvent.serialize("first"))

  # test "Each server sent event is processed as it is received" do
  #   {port, listen_socket} = listen()
  #   {:ok, _client} = AutoConnect.start_link(port)

  #   {:ok, socket} = accept(listen_socket)
  #   {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
  #   assert String.contains?(first_request, "accept: text/event-stream")
  #   assert String.contains?(first_request, "\r\n\r\n")

  #   :ok = :gen_tcp.send(socket, [@first_response, @event])
  #   assert_receive {:connect, response = %Raxx.Response{}}, 5_000
  #   assert response.status == 200
  #   assert Raxx.get_header(response, "content-type") == "text/event-stream"

  #   assert_receive %ServerSentEvent{lines: ["first"]}, 5_000

  #   :ok = :gen_tcp.send(socket, Raxx.HTTP1.serialize_chunk(ServerSentEvent.serialize("second")))
  #   assert_receive %ServerSentEvent{lines: ["second"]}, 5_000
  # end

  # defp listen(port \\ 0) do
  #   {:ok, listen_socket} = :gen_tcp.listen(port, mode: :binary, packet: :raw, active: false)
  #   {:ok, port} = :inet.port(listen_socket)
  #   {port, listen_socket}
  # end

  # defp accept(listen_socket) do
  #   :gen_tcp.accept(listen_socket, 1_000)
  # end
end
