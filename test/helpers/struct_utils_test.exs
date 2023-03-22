defmodule StructUtilsTest do
  use ExUnit.Case, async: true

  alias OpenOwl.Helpers.StructUtils

  defmodule TestStruct do
    @enforce_keys [:title]
    defstruct [:id, :title]
  end

  defmodule AnotherTestStruct do
    defstruct [:id, :title]
  end

  describe "to_struct/2 creates the specified struct" do
    test "with passed empty Map attrs" do
      assert StructUtils.to_struct(TestStruct, %{}) == %TestStruct{id: nil, title: nil}

      assert StructUtils.to_struct(TestStruct, %{}) |> Map.to_list() == [
               __struct__: StructUtilsTest.TestStruct,
               id: nil,
               title: nil
             ]
    end

    test "with passed string Map attrs" do
      assert StructUtils.to_struct(TestStruct, %{"id" => "id"}) == %TestStruct{
               id: "id",
               title: nil
             }

      assert StructUtils.to_struct(TestStruct, %{"title" => "title"}) == %TestStruct{
               id: nil,
               title: "title"
             }
    end

    test "with passed atom Map attrs" do
      assert StructUtils.to_struct(TestStruct, %{id: "id"}) == %TestStruct{
               id: "id",
               title: nil
             }

      assert StructUtils.to_struct(TestStruct, %{title: "title"}) == %TestStruct{
               id: nil,
               title: "title"
             }
    end

    test "with passed struct attrs" do
      assert StructUtils.to_struct(TestStruct, %AnotherTestStruct{}) |> Map.to_list() == [
               __struct__: StructUtilsTest.TestStruct,
               id: nil,
               title: nil
             ]

      assert StructUtils.to_struct(TestStruct, %AnotherTestStruct{id: "id"}) == %TestStruct{
               id: "id",
               title: nil
             }

      assert StructUtils.to_struct(TestStruct, %AnotherTestStruct{title: "title"}) == %TestStruct{
               id: nil,
               title: "title"
             }
    end
  end
end
