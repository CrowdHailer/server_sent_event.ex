defmodule Splitting do
  @new_line_regex ~r/\R/
  @new_line_sequences ["\r\n", "\r", "\n"]

  def with_regex(stream) do
    String.split(stream, @new_line_regex, parts: 2)
  end

  def with_binary_split(stream) do
    # not global means just two parts
    :binary.split(stream, @new_line_sequences)
  end

  def with_binary_split_compiled(stream, compiled_pattern) do
    # not global means just two parts
    :binary.split(stream, compiled_pattern)
  end

  def with_elixir_string_split(stream) do
    String.split(stream, @new_line_sequences, parts: 2)
  end

  def new_line_sequences() do
    @new_line_sequences
  end
end

input = "aaaaaaaaaa\rbbbbbbbb\rccccccccccc\r\n" |> String.duplicate(10000)

IO.puts("length: #{String.length(input)}")
IO.inspect(input)

compiled_pattern = :binary.compile_pattern(Splitting.new_line_sequences())

Benchee.run(%{
  "with_regex" => fn -> Splitting.with_regex(input) end,
  "with_binary_split" => fn -> Splitting.with_binary_split(input) end,
  "with_binary_split_compiled" => fn -> Splitting.with_binary_split_compiled(input, compiled_pattern) end,
  "with_elixir_string_split" => fn -> Splitting.with_elixir_string_split(input) end
})
