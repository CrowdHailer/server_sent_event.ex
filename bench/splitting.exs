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

  def with_erlang_regex(stream) do
    :re.split(stream, @new_line_regex.re_pattern, parts: 2, return: :binary, match_limit: 2)
  end

  def with_lazy_compiled_pattern(stream) do
    compiled_pattern =
      try do
        :ets.lookup_element(:splitting, :new_line_pattern, 2)
      rescue
        _e in ArgumentError -> :none
      end

    case compiled_pattern do
      :none ->
        IO.puts "COMPILING!"
        compiled_pattern = new_line_sequences()
        try do
          :splitting = :ets.new(:splitting, [:set, :protected, :named_table])
          :ets.insert(:splitting, {:new_line_pattern, compiled_pattern})
        rescue
          _e -> :ok
        end
        :binary.split(stream, compiled_pattern)

      pattern ->
        :binary.split(stream, pattern)
    end
  end

  def new_line_sequences() do
    @new_line_sequences
  end
end

input_part = "aaaaaaaaaa\rbbbbbbbb\rccccccccccc\r\n"
IO.inspect Splitting.with_erlang_regex(input_part)
IO.inspect Splitting.with_lazy_compiled_pattern(input_part)

input = String.duplicate(input_part, 1000)
IO.puts("length: #{String.length(input)}")

compiled_pattern = :binary.compile_pattern(Splitting.new_line_sequences())

Benchee.run(%{
  "with_regex" => fn -> Splitting.with_regex(input) end,
  "with_binary_split" => fn -> Splitting.with_binary_split(input) end,
  "with_binary_split_compiled" => fn -> Splitting.with_binary_split_compiled(input, compiled_pattern) end,
  "with_elixir_string_split" => fn -> Splitting.with_elixir_string_split(input) end,
  "with_erlang_regex" => fn -> Splitting.with_erlang_regex(input) end,
  "with_lazy_compiled_pattern" => fn -> Splitting.with_lazy_compiled_pattern(input) end
})
