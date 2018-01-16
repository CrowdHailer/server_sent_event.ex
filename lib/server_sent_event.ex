defmodule ServerSentEvent do
  alias __MODULE__, as: This

  @moduledoc """
  **Push updates to Web clients over HTTP or using dedicated server-push protocols.**

  Messages are sent in the following form, with the `text/event-stream` MIME type:

  ```sh
  data: This is the first message.

  data: This is the second message, it
  data: has two lines.

  event: custom
  data: This message has event type 'custom'.

  ```

  A living standard is available from [WHATWG](https://html.spec.whatwg.org/#server-sent-events).

  The contents of a server-sent-event are:

  | **type** | The type of an event |
  | **lines** | The data contents of the event split by line |
  | **id** | Value to send in `last-event-id` header when reconnecting |
  | **retry** | Time to wait before retrying connection in milliseconds |
  | **comments** | Any lines from original block that were marked as comments |
  """

  @new_line ~r/\R/

  @type t :: %This{
    type: term(),
    lines: [term()],
    id: term(),
    retry: nil,
    comments: [term()]
  }

  defstruct [
    type: nil,
    lines: [],
    id: nil,
    retry: nil,
    comments: []
  ]

  @doc """
  This event stream format's MIME type is `text/event-stream`.
  """
  @spec mime_type() :: String.t
  def mime_type() do
    "text/event-stream"
  end

  @doc """
  Does the event have any data lines.

  An event without any data lines will not trigger any browser events.
  """
  @spec empty?(event :: t()) :: boolean
  def empty?(_event = %{lines: []}), do: true
  def empty?(_event = %{lines: _}), do: false

  @doc """
  Format an event to be sent as part of a stream

  **NOTE:** Each data/comment line must be without new line charachters.

  ## Examples
  *In these examples this module has been aliased to `SSE`*.

      iex> %SSE{type: "greeting", lines: ["Hi,", "there"], comments: ["comment"]}
      ...> |> SSE.serialize()
      "event: greeting\\n: comment\\ndata: Hi,\\ndata: there\\n\\n"

      iex> %SSE{lines: ["message with id"], id: "some-id"}
      ...> |> SSE.serialize()
      "data: message with id\\nid: some-id\\n\\n"

      iex> %SSE{lines: ["message setting retry to 10s"], retry: 10_000}
      ...> |> SSE.serialize()
      "data: message setting retry to 10s\\nretry: 10000\\n\\n"
  """
  @spec serialize(event :: t()) :: String.t
  def serialize(event = %__MODULE__{}) do
    type_line(event)
    ++ comment_lines(event)
    ++ data_lines(event)
    ++ id_line(event)
    ++ retry_line(event)
    ++ ["\n"]
    |> Enum.join("\n")
  end

  defp type_line(%{type: nil}) do
    []
  end
  defp type_line(%{type: type}) do
    single_line?(type) || raise "Bad"
    ["event: " <> type]
  end

  defp comment_lines(%{comments: comments}) do
    Enum.map(comments, fn(comment) ->
      single_line?(comment) || raise "Bad"
      ": " <> comment
    end)
  end

  defp data_lines(%{lines: lines}) do
    Enum.map(lines, fn(line) ->
      single_line?(line) || raise "Bad"
      "data: " <> line
    end)
  end

  defp id_line(%{id: nil}) do
    []
  end
  defp id_line(%{id: id}) do
    single_line?(id) || raise "Bad"
    ["id: " <> id]
  end

  defp retry_line(%{retry: nil}) do
    []
  end
  defp retry_line(%{retry: retry}) when is_integer(retry) do
    ["retry: " <> to_string(retry)]
  end

  defp single_line?(text) do
    length(String.split(text, @new_line, parts: 2)) == 1
  end

  @doc """
  Parse the next event from text stream, if present.

  ## Examples
  *In these examples this module has been aliased to `SSE`*.

      iex> SSE.parse("data: This is the first message\\n\\n")
      {:ok, {%SSE{lines: ["This is the first message"]}, ""}}

      iex> SSE.parse("data:First whitespace character is optional\\n\\n")
      {:ok, {%SSE{lines: ["First whitespace character is optional"]}, ""}}

      iex> SSE.parse("data: This message\\ndata: has two lines.\\n\\n")
      {:ok, {%SSE{lines: ["This message", "has two lines."]}, ""}}

      iex> SSE.parse("data: This is the first message\\n\\nrest")
      {:ok, {%SSE{lines: ["This is the first message"]}, "rest"}}

      iex> SSE.parse("data: This message is not complete")
      {:ok, {nil, "data: This message is not complete"}}

      iex> SSE.parse("This line is invalid\\nit doesn't contain a colon\\n")
      {:error, {:malformed_line, "This line is invalid"}}

      iex> SSE.parse("event: custom\\ndata: This message is type custom\\n\\n")
      {:ok, {%SSE{type: "custom", lines: ["This message is type custom"]}, ""}}

      iex> SSE.parse("id: 100\\ndata: This message has an id\\n\\n")
      {:ok, {%SSE{id: "100", lines: ["This message has an id"]}, ""}}

      iex> SSE.parse("retry: 5000\\ndata: This message retries after 5s.\\n\\n")
      {:ok, {%SSE{retry: 5000, lines: ["This message retries after 5s."]}, ""}}

      iex> SSE.parse(": This is a comment\\n\\n")
      {:ok, {%SSE{comments: ["This is a comment"]}, ""}}

      iex> SSE.parse("data: data can have more :'s in it'\\n\\n")
      {:ok, {%SSE{lines: ["data can have more :'s in it'"]}, ""}}

  """
  # parse_block block has comments event does not
  @spec parse(String.t) :: {:ok, {event :: t() | nil, rest :: String.t}} | {:error, term}
  def parse(stream) do
    do_parse(stream, %__MODULE__{}, stream)
  end

  defp do_parse(stream, event, original) do
    case pop_line(stream) do
      nil ->
        {:ok, {nil, original}}
      {"", rest} ->
        {:ok, {event, rest}}
      {line, rest} ->
        with {:ok, event} <- process_line(line, event),
        do: do_parse(rest, event, original)
    end
  end

  defp pop_line(stream) do
    case String.split(stream, @new_line, parts: 2) do
      [^stream] ->
        nil
      [line, rest] ->
        {line, rest}
    end
  end

  defp process_line(line, event) do
    case String.split(line, ~r/: ?/, parts: 2) do
      ["", value] ->
        {:ok, process_field("comment", value, event)}
      [field, value] ->
        {:ok, process_field(field, value, event)}
      _ ->
        {:error, {:malformed_line, line}}
    end
  end

  defp process_field("event", type, event) do
    Map.put(event, :type, type)
  end
  defp process_field("data", line, event = %{lines: lines}) do
    %{event | lines: lines ++ [line]}
  end
  defp process_field("id", id, event) do
    Map.put(event, :id, id)
  end
  defp process_field("retry", timeout, event) do
    {timeout, ""} = Integer.parse(timeout)
    Map.put(event, :retry, timeout)
  end
  defp process_field("comment", comment, event = %{comments: comments}) do
    %{event | comments: comments ++ [comment]}
  end
end
