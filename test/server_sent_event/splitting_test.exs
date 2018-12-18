defmodule ServerSentEvent.SplittingTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :property

  test "all approaches to splitting work the same way" do
    check all input <- StreamData.string([?a..?f, ?ż, ?\r, ?\n]),
              max_runs: 500,
              max_run_time: 100 do
      assert with_binary_split(input) == with_regex(input)
      assert with_elixir_string_split(input) == with_regex(input)
    end
  end

  @new_line_regex ~r/\R/
  @new_line_sequences ["\r\n", "\r", "\n"]

  def with_regex(stream) do
    String.split(stream, @new_line_regex, parts: 2)
  end

  def with_binary_split(stream) do
    # not global means just two parts
    :binary.split(stream, @new_line_sequences)
  end

  def with_elixir_string_split(stream) do
    String.split(stream, @new_line_sequences, parts: 2)
  end
end
