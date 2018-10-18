defmodule ServerSentEvent.ClientPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :property

  alias ServerSentEvent.ClientTest.AutoConnect

  {head, :chunked} =
    Raxx.HTTP1.serialize_response(
      Raxx.response(:ok)
      |> Raxx.set_header("content-type", "text/event-stream")
      |> Raxx.set_body(true)
    )

  @first_response head

  test "the client will reconstruct sses regardless of how they get split between packets" do
    check all sses <- StreamData.list_of(any_sse(), min_length: 1, max_length: 20),
              split_points <- StreamData.list_of(StreamData.integer(0..10_000), max_length: 100),
              sses_in_chunk <- StreamData.integer(1..3),
              max_runs: 600,
              max_run_time: 10_000 do
      # preparing the connection
      {port, listen_socket} = listen()
      {:ok, client} = AutoConnect.start_link(port)

      {:ok, socket} = accept(listen_socket)
      {:ok, first_request} = :gen_tcp.recv(socket, 0, 1_000)
      assert String.contains?(first_request, "accept: text/event-stream")
      assert String.contains?(first_request, "\r\n\r\n")

      :ok = :gen_tcp.send(socket, [@first_response])
      assert_receive {:connect, response = %Raxx.Response{}}, 5_000
      assert response.status == 200
      assert response.body == true
      assert Raxx.get_header(response, "content-type") == "text/event-stream"

      # preparing the response
      whole_response =
        sses
        |> Enum.map(&ServerSentEvent.serialize(&1))
        |> Enum.chunk_every(sses_in_chunk)
        |> Enum.map(&Enum.join(&1, ""))
        |> Enum.map(&Raxx.HTTP1.serialize_chunk/1)
        |> Enum.join("")

      response_length = byte_size(whole_response)

      split_pairs =
        split_points
        |> Enum.reject(&(&1 >= response_length))
        |> (fn points -> points ++ [0, response_length] end).()
        |> Enum.uniq()
        |> Enum.sort()
        |> Enum.chunk_every(2, 1, :discard)

      packets =
        split_pairs
        |> Enum.map(fn [from, to] -> binary_part(whole_response, from, to - from) end)

      assert Enum.join(packets, "") == whole_response

      Enum.each(packets, fn packet ->
        :ok = :gen_tcp.send(socket, packet)
        # try to make sure erlang's magic is not going to merge the packets
        Process.sleep(1)
      end)

      Enum.each(sses, fn sse ->
        received = assert_receive %ServerSentEvent{}, 5_000
        assert sse == received
      end)

      # cleanup, otherwise we run out of ports/sockets/file descriptors
      send(client, :stop)
      :ok = :gen_tcp.close(socket)
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
        |> Enum.join("")

      assert {:ok, {^sses, ""}} = ServerSentEvent.parse_all(serialized)
    end
  end

  def any_sse() do
    StreamData.frequency([
      {9, simple_sse()},
      {1, comment_sse()}
    ])
  end

  def ascii_string_with_newlines do
    StreamData.string(:ascii)
    |> StreamData.list_of()
    |> StreamData.map(&Enum.join(&1, "\n"))
  end

  def simple_sse() do
    data = ascii_string_with_newlines()
    int_id = StreamData.positive_integer()
    type = StreamData.member_of(["foo", "bar", "baz"])

    {data, int_id, type}
    |> StreamData.tuple()
    |> StreamData.map(fn {data, int_id, type} ->
      id = Integer.to_string(int_id)
      sse = ServerSentEvent.new(data)

      %ServerSentEvent{
        sse
        | id: id,
          type: type
      }
    end)
    |> StreamData.filter(&(&1.lines != []))
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
