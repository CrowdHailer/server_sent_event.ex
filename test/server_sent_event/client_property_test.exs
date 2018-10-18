defmodule ServerSentEvent.ClientPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :property

  test "sample test" do
    check all int1 <- StreamData.integer(), int2 <- StreamData.integer() do
      assert int1 + int2 == int2 + int1
    end
  end

  alias ServerSentEvent.ClientTest.AutoConnect

  {head, :chunked} =
    Raxx.HTTP1.serialize_response(
      Raxx.response(:ok)
      |> Raxx.set_header("content-type", "text/event-stream")
      |> Raxx.set_body(true)
    )

  @first_response head
  @event Raxx.HTTP1.serialize_chunk(ServerSentEvent.serialize("first"))

  test "Each server sent event is processed as it is received" do
    check all _int <- StreamData.integer(), max_runs: 1_000, max_run_time: 1_000 do
      {port, listen_socket} = listen()
      {:ok, client} = AutoConnect.start_link(port)

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

      # cleanup, otherwise we run out of ports/sockets/file descriptors
      send client, :stop
      :ok = :gen_tcp.close(socket)
    end
  end

  test "an sse can carry any string" do
    check all string <- non_empty_ascii_string() do
      sse = ServerSentEvent.new(string)
      assert sse.lines != []
    end
  end

  test "simple sse generation" do
    check all sse <- simple_sse() do
      assert %ServerSentEvent{
        lines: lines,
        id: id,
        comments: [],
        type: type
      } = sse
      assert is_binary(id)
      assert is_list(lines)
      assert Enum.all?(lines, &String.valid?(&1))
      assert is_binary(type)
    end
  end

  test "comment sse generation" do
    check all sse <- comment_sse() do
      assert %ServerSentEvent{
        comments: comments
      } = sse
      assert is_list(comments)
      assert Enum.all?(comments, &String.valid?(&1))
    end
  end

  test "sse encoding and decoding" do
    check all sses <- StreamData.list_of(any_sse(), max_length: 10) do
      serialized =
        sses
        |> Enum.map(&ServerSentEvent.serialize/1)
        |> Enum.join("\n\n")
      assert {:ok, {^sses, ""}} = ServerSentEvent.parse_all(serialized <> "\n\n")
    end
  end

  test "filtering" do
    non_empty_strings =
      StreamData.string(:ascii)
      |> StreamData.filter(& &1 != "")

    check all nes <- non_empty_strings do
      assert nes != ""
    end
  end

  def any_sse() do
    StreamData.frequency([
      {9, simple_sse()},
      {1, comment_sse()}
    ])
  end

  def non_empty_ascii_string do
    StreamData.string(:ascii)
    |> StreamData.list_of()
    |> StreamData.map(&Enum.join(&1, "\n"))
    |> StreamData.filter(& &1 != "")
  end

  def simple_sse() do
    data = non_empty_ascii_string()
    int_id = StreamData.positive_integer()
    type = StreamData.member_of(["foo", "bar", "baz"])

    {data, int_id, type}
    |> StreamData.tuple()
    |> StreamData.map(fn {data, int_id, type} ->
      id = Integer.to_string(int_id)
      sse = ServerSentEvent.new(data)
      %ServerSentEvent{
        sse | id: id, type: type
      }
    end)
    |> StreamData.filter(& &1.lines != [])
  end

  def comment_sse() do
    StreamData.string(:alphanumeric)
    |> StreamData.list_of(min_length: 1, max_length: 3)
    |> StreamData.map(fn comments ->
      %ServerSentEvent{comments: comments}
    end)
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
