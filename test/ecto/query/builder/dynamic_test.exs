defmodule Ecto.Query.Builder.DynamicTest do
  use ExUnit.Case, async: true

  import Ecto.Query.Builder.Dynamic
  doctest Ecto.Query.Builder.Dynamic

  import Ecto.Query

  defp query do
    from p in "posts", join: c in "comments", on: p.id == c.post_id
  end

  describe "expand/2" do
    test "without params" do
      dynamic = dynamic([p], p.foo == true)
      assert {expr, params, _, _} = expand(query(), dynamic)
      assert expr ==
             {:==, [], [{{:., [], [{:&, [], [0]}, :foo]}, [], []},
                        %Ecto.Query.Tagged{tag: nil, value: true, type: {0, :foo}}]}
      assert params == []
    end

    test "with params" do
      dynamic = dynamic([p], p.foo == ^1)
      assert {expr, params, _, _} = expand(query(), dynamic)
      assert Macro.to_string(expr) == "&0.foo() == ^0"
      assert params == [{1, {0, :foo}}]
    end

    test "with dynamic interpolation" do
      dynamic = dynamic([p], p.bar == ^2)
      dynamic = dynamic([p], p.foo == ^1 and ^dynamic or p.baz == ^3)
      assert {expr, params, _, _} = expand(query(), dynamic)
      assert Macro.to_string(expr) ==
             "&0.foo() == ^0 and &0.bar() == ^2 or &0.baz() == ^1"
      assert params == [{1, {0, :foo}}, {3, {0, :baz}}, {2, {0, :bar}}]
    end

    test "with nested dynamic interpolation" do
      dynamic = dynamic([p], p.bar2 == ^"bar2")
      dynamic = dynamic([p], p.bar1 == ^"bar1" or ^dynamic or p.bar3 == ^"bar3")
      dynamic = dynamic([p], p.foo == ^"foo" and ^dynamic and p.baz == ^"baz")
      assert {expr, params, _, _} = expand(query(), dynamic)
      assert Macro.to_string(expr) ==
             "&0.foo() == ^0 and (&0.bar1() == ^2 or &0.bar2() == ^4 or &0.bar3() == ^3) and &0.baz() == ^1"
      assert params == [{"foo", {0, :foo}}, {"baz", {0, :baz}}, {"bar1", {0, :bar1}},
                        {"bar3", {0, :bar3}}, {"bar2", {0, :bar2}}]
    end

    test "with multiple bindings" do
      dynamic = dynamic([p, c], p.bar == c.bar)
      dynamic = dynamic([p], p.foo == ^"foo" and ^dynamic and p.baz == ^"baz")
      assert {expr, params, _, _} = expand(query(), dynamic)
      assert Macro.to_string(expr) ==
             "&0.foo() == ^0 and &0.bar() == &1.bar() and &0.baz() == ^1"
      assert params == [{"foo", {0, :foo}}, {"baz", {0, :baz}}]
    end

    test "with ... bindings" do
      dynamic = dynamic([..., c], c.bar == ^"bar")
      dynamic = dynamic([p], p.foo == ^"foo" and ^dynamic and p.baz == ^"baz")
      assert {expr, params, _, _} = expand(query(), dynamic)
      assert Macro.to_string(expr) ==
             "&0.foo() == ^0 and &1.bar() == ^2 and &0.baz() == ^1"
      assert params == [{"foo", {0, :foo}}, {"baz", {0, :baz}}, {"bar", {1, :bar}}]
    end
  end
end
