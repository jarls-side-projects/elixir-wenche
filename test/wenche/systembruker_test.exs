defmodule Wenche.SystembrukerTest do
  use ExUnit.Case, async: true

  alias Wenche.Systembruker

  describe "system_id/1" do
    test "generates correct system ID format" do
      assert Systembruker.system_id("912345678") == "912345678_wenche"
    end
  end
end
