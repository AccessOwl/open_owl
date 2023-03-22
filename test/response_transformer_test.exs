defmodule ResponseTransformerTest do
  use ExUnit.Case, async: true

  alias OpenOwl.ResponseTransformer

  @record1 %{
    "email" => "batman@wayne.org",
    "emailConfirmed" => true,
    "id" => 123,
    "lastLoginDate" => "2022-12-13T14:07:59.371Z",
    "name" => "Bruce Wayne",
    "team_role" => %{
      "level" => 999,
      "pending" => false,
      "pending_email" => nil,
      "resource_type" => "team",
      "role" => %{
        "name" => "Heroes",
        "id" => "abc"
      },
      "user_id" => "456"
    }
  }
  @record2 %{@record1 | "email" => "robin@wayne.org", "name" => "Robin"}
  @map_list [@record1, @record2]

  describe "records_to_list_with_header/1" do
    test "returns table structure with header" do
      assert ResponseTransformer.records_to_list_with_header(@map_list) == [
               [
                 "email",
                 "emailConfirmed",
                 "id",
                 "lastLoginDate",
                 "name",
                 "team_role.level",
                 "team_role.pending",
                 "team_role.pending_email",
                 "team_role.resource_type",
                 "team_role.role.id",
                 "team_role.role.name",
                 "team_role.user_id"
               ],
               [
                 "batman@wayne.org",
                 true,
                 123,
                 "2022-12-13T14:07:59.371Z",
                 "Bruce Wayne",
                 999,
                 false,
                 nil,
                 "team",
                 "abc",
                 "Heroes",
                 "456"
               ],
               [
                 "robin@wayne.org",
                 true,
                 123,
                 "2022-12-13T14:07:59.371Z",
                 "Robin",
                 999,
                 false,
                 nil,
                 "team",
                 "abc",
                 "Heroes",
                 "456"
               ]
             ]
    end

    test "returns empty list if input was an empty list" do
      assert ResponseTransformer.records_to_list_with_header([]) == []
    end

    test "raises error if it is not a list" do
      assert_raise FunctionClauseError, fn ->
        ResponseTransformer.records_to_list_with_header(@record1)
      end
    end
  end

  describe "list_with_header_to_csv/1" do
    test "returns a CSV string" do
      assert ResponseTransformer.list_with_header_to_csv([]) == ""

      assert ResponseTransformer.list_with_header_to_csv([~w(col_a col_b), ~w(hey you)]) ==
               "col_a,col_b\r\nhey,you\r\n"
    end

    test "raises error if it is not a list" do
      assert_raise FunctionClauseError, fn ->
        ResponseTransformer.list_with_header_to_csv(%{})
      end
    end
  end

  describe "flat_record/1" do
    test "returns zero-level map untouched" do
      record = %{"hey" => "you", "what" => 4, "or" => true}

      assert ResponseTransformer.flat_record(record) == record
    end

    test "ignores fields that hold lists with maps" do
      record = %{
        "hey" => "you",
        "simple_array" => ["you", 1],
        "complex_array" => [%{"sub_map" => 1}]
      }

      assert ResponseTransformer.flat_record(record) == %{
               "hey" => "you",
               "simple_array" => ["you", 1]
             }
    end

    test "returns one-level map with concatted field names" do
      record = %{"hey" => "you", "what" => 4, "deep" => %{"name" => "cracker", "good" => true}}

      assert ResponseTransformer.flat_record(record) == %{
               "hey" => "you",
               "what" => 4,
               "deep.name" => "cracker",
               "deep.good" => true
             }
    end

    test "returns multi-level map with concatted field names" do
      assert ResponseTransformer.flat_record(@record1) == %{
               "email" => "batman@wayne.org",
               "emailConfirmed" => true,
               "id" => 123,
               "lastLoginDate" => "2022-12-13T14:07:59.371Z",
               "name" => "Bruce Wayne",
               "team_role.level" => 999,
               "team_role.pending" => false,
               "team_role.pending_email" => nil,
               "team_role.resource_type" => "team",
               "team_role.role.name" => "Heroes",
               "team_role.role.id" => "abc",
               "team_role.user_id" => "456"
             }
    end
  end
end
