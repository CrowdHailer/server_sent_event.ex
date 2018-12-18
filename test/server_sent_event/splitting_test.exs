defmodule ServerSentEvent.SplittingTest do
  alias ServerSentEvent.Splitting

  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :property
  @moduletag :splitting
  @moduletag :benchmark

  test "all approaches to splitting work the same way" do
    check all input <- StreamData.string(:ascii),
              max_runs: 500,
              max_run_time: 600 do
      assert Splitting.with_binary_split(input) == Splitting.with_regex(input)
      assert Splitting.with_elixir_string_split(input) == Splitting.with_regex(input)
    end
  end
end
