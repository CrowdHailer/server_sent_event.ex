defmodule ServerSentEvent.Splitting do
  @new_line_regex ~r/\R/
  @new_line_sequences ["\r\n", "\r", "\n"]

  # @new_line_sequences_compiled :binary.compile_pattern(@new_line_sequences)

  def with_regex(stream) do
    String.split(stream, @new_line_regex, parts: 2)
  end

  def with_binary_split(stream) do
    # not global means just two parts
    :binary.split(stream, @new_line_sequences)
  end

  def with_binary_split_compiled(stream) do
    # not global means just two parts
    compiled_pattern = :binary.compile_pattern(@new_line_sequences)
    :binary.split(stream, compiled_pattern)
  end

  def with_elixir_string_split(stream) do
    String.split(stream, @new_line_sequences, parts: 2)
  end
end
