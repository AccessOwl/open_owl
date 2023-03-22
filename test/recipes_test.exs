defmodule RecipesTest do
  use ExUnit.Case, async: true

  alias OpenOwl.Recipes.Recipe
  alias OpenOwl.Recipes.Action
  alias OpenOwl.Recipes

  @test_recipe1 %Recipe{
    login_url: "https://example1.com",
    destination_url_pattern: "dup",
    username_selector: "us",
    password_selector: "ps"
  }
  @test_recipe2 %{@test_recipe1 | login_url: "https://example2.com"}
  @action1 %Action{
    name: :download,
    http_method: :get,
    url: "https://example.com/:url_id",
    headers: [{"x-1", "cool_:header_id_one"}, {"x-2", ":url_id/:header_id_two"}]
  }
  @action2 %Action{name: :list, http_method: :get, url: "https://example.com/:url_id"}

  describe "load_recipes/1" do
    test "returns parsed recipes from a yaml file" do
      assert {:ok, recipes} = Recipes.load_recipes("test/fixtures/test_recipes.yml")

      assert recipes == %{
               adobe: %OpenOwl.Recipes.Recipe{
                 login_url: "https://adminconsole.adobe.com/team",
                 destination_url_pattern: "https://adminconsole.adobe.com/**/overview",
                 username_selector: "internal:label=\"Email address\"i",
                 password_selector: "internal:label=\"Password\"i",
                 actions: [
                   %OpenOwl.Recipes.Action{
                     name: "download_users",
                     http_method: :get,
                     url: "https://adobe.io/api/sth",
                     populate_placeholders_from_session_storage:
                       ~w(client_id tokenValue roles.organization),
                     response_path: nil,
                     headers: [
                       {"x-api-key", ":client_id"},
                       {"authorization", "Bearer :tokenValue"}
                     ],
                     pagination: %OpenOwl.PaginationStrategy.PageParamsInUrl{
                       strategy: "page_params_in_url",
                       page_query_param: "p"
                     }
                   }
                 ]
               },
               badobe: %OpenOwl.Recipes.Recipe{
                 login_url: "https://adminconsole.adobe.com/team",
                 destination_url_pattern: "https://adminconsole.adobe.com/**/overview",
                 username_selector: "internal:label=\"Email address\"i",
                 password_selector: "internal:label=\"Password\"i",
                 actions: [
                   %OpenOwl.Recipes.Action{
                     name: "download_users",
                     http_method: :get,
                     url: "https://adobe.io/api/sth",
                     response_path: nil,
                     pagination: %OpenOwl.PaginationStrategy.OffsetParamsInUrl{
                       strategy: "offset_params_in_url",
                       offset_query_param: "start_offset",
                       limit_query_param: "size"
                     }
                   }
                 ]
               },
               asana: %OpenOwl.Recipes.Recipe{
                 login_url: "https://asana.com/login",
                 destination_url_pattern: "https://asana.com/app/**",
                 username_selector: "#a",
                 password_selector: "#b",
                 actions: [
                   %OpenOwl.Recipes.Action{
                     name: "change_sth",
                     http_method: :post,
                     body: "{\"query\":\"query Users\"}",
                     url: "https://asana.com/api/sth",
                     response_path: "meta.data",
                     headers: [{"X-Dynamic", ":team_id"}, {"X-Static", "Blub 1"}]
                   }
                 ]
               },
               calendly: %OpenOwl.Recipes.Recipe{
                 login_url: "https://calendly.com/app/login",
                 destination_url_pattern: "https://calendly.com/event_types/user/me",
                 username_selector: "input[placeholder='email address']",
                 password_selector: "input[placeholder=password]",
                 actions: [
                   %OpenOwl.Recipes.Action{
                     name: "download_users",
                     http_method: :get,
                     url: "https://calendly.com/api/organization/memberships",
                     response_path: "results",
                     pagination: %OpenOwl.PaginationStrategy.NextPageInBody{
                       strategy: "next_page_in_body",
                       next_page_response_path: "pagination.next_page",
                       page_query_param: "page"
                     },
                     headers: []
                   }
                 ]
               },
               loom: %OpenOwl.Recipes.Recipe{
                 login_url: "https://loom.com/login",
                 destination_url_pattern: "https://loom.com/app/**",
                 username_selector: "#a",
                 password_selector: "#b",
                 actions: [
                   %OpenOwl.Recipes.Action{
                     name: "download_users",
                     http_method: :get,
                     url: "https://loom.com/api/v1",
                     response_path: "data",
                     pagination: %OpenOwl.PaginationStrategy.NextCursorInBodyToSendAsJson{
                       strategy: "next_cursor_in_body_to_send_as_json",
                       next_cursor_response_path: "pagination.next_page",
                       has_next_page_response_path: "pagination.has_next_page",
                       json_body_cursor_path: "variables.after"
                     },
                     headers: []
                   }
                 ]
               },
               miro: %OpenOwl.Recipes.Recipe{
                 login_url: "https://miro.com/login",
                 destination_url_pattern: "https://miro.com/app/**",
                 username_selector: "data-testid=mr1",
                 password_selector: "data-testid=mr2",
                 actions: [
                   %OpenOwl.Recipes.Action{
                     name: "download_users",
                     http_method: :get,
                     url: "https://miro.com/api/v1/accounts/:team_id/users",
                     response_path: "data",
                     pagination: %OpenOwl.PaginationStrategy.UrlInBody{
                       strategy: "url_in_body",
                       next_url_response_path: "nextLink"
                     },
                     headers: []
                   }
                 ]
               }
             }
    end

    test "returns error if file was not found" do
      assert {:error, %YamlElixir.FileNotFoundError{}} =
               Recipes.load_recipes("test/fixtures/not_existent.yml")
    end
  end

  test "get_recipe/2 returns recipe for a slug" do
    recipes = %{test1: @test_recipe1, test2: @test_recipe2}

    assert Recipes.get_recipe(%{}, :test) == nil
    assert Recipes.get_recipe(recipes, :test) == nil
    assert Recipes.get_recipe(recipes, :test1) == @test_recipe1
    assert Recipes.get_recipe(recipes, :test2) == @test_recipe2
    assert Recipes.get_recipe(recipes, "test") == nil
    assert Recipes.get_recipe(recipes, "test1") == @test_recipe1
    assert Recipes.get_recipe(recipes, "test2") == @test_recipe2
  end

  test "get_action_for_name/2 returns action for name or nil" do
    actions = [@action1, @action2]
    assert Recipes.get_action_for_name(actions, :not_existent) == nil
    assert Recipes.get_action_for_name(actions, :download) == @action1
    assert Recipes.get_action_for_name(actions, :list) == @action2
  end

  describe "get_required_parameters_for_recipe/2" do
    test "returns required parameters for special recipe action login" do
      recipe_login_param = %{@test_recipe1 | login_url: "https://example.com/:org_id/:bla"}

      recipe_dest_param = %{
        @test_recipe1
        | destination_url_pattern: "https://example.com/*/:bla"
      }

      recipe_both_duplicated = %{
        @test_recipe1
        | login_url: "https://example.com/:org_id/:bla",
          destination_url_pattern: "https://example.com/*/:bla"
      }

      assert Recipes.get_required_parameters_for_recipe(@test_recipe1, "login") == [
               :username,
               :password
             ]

      assert Recipes.get_required_parameters_for_recipe(recipe_login_param, "login") == [
               :username,
               :password,
               :org_id,
               :bla
             ]

      assert Recipes.get_required_parameters_for_recipe(recipe_dest_param, "login") == [
               :username,
               :password,
               :bla
             ]

      assert Recipes.get_required_parameters_for_recipe(recipe_both_duplicated, "login") == [
               :username,
               :password,
               :bla,
               :org_id
             ]
    end

    test "returns required parameters for dynamic recipe action" do
      recipe_base = %{
        @test_recipe1
        | login_url: "https://example.com/:org_id",
          destination_url_pattern: ":dest_id"
      }

      recipe_with_actions = %{recipe_base | actions: [@action1, @action2]}

      # ignores login parameters
      assert Recipes.get_required_parameters_for_recipe(recipe_with_actions, :not_existent) == []

      assert Recipes.get_required_parameters_for_recipe(recipe_with_actions, :download) == [
               :url_id,
               :header_id_two,
               :header_id_one
             ]

      assert Recipes.get_required_parameters_for_recipe(recipe_with_actions, :list) == [:url_id]
    end
  end

  describe "validate_recipe_parameters/3" do
    @recipe_with_params %{
      @test_recipe1
      | login_url: "https://example.com/:org_id",
        actions: [@action1]
    }

    test "returns ok with passed parameter map if all required parameters are present" do
      # without params
      login_parameters_pure = %{username: "u", password: "p"}

      assert Recipes.validate_recipe_parameters(@test_recipe1, "login", login_parameters_pure) ==
               {:ok, login_parameters_pure}

      login_parameters_not_existing = Map.put(login_parameters_pure, :not_existent, 1)

      assert Recipes.validate_recipe_parameters(
               @test_recipe1,
               "login",
               login_parameters_not_existing
             ) ==
               {:ok, login_parameters_not_existing}

      login_parameters_required = Map.put(login_parameters_pure, :org_id, "1")

      assert Recipes.validate_recipe_parameters(
               @recipe_with_params,
               "login",
               login_parameters_required
             ) ==
               {:ok, login_parameters_required}

      action_parameters = %{
        url_id: "1",
        header_id_two: 2,
        header_id_one: "a3"
      }

      assert Recipes.validate_recipe_parameters(
               @recipe_with_params,
               @action1.name,
               action_parameters
             ) ==
               {:ok, action_parameters}
    end

    test "returns error with list of missing parameters if not all required parameters are present" do
      assert Recipes.validate_recipe_parameters(@recipe_with_params, "login", %{wrong: 1}) ==
               {:error, [:username, :password, :org_id]}

      assert Recipes.validate_recipe_parameters(@recipe_with_params, "login", %{
               password: "p",
               wrong: 1
             }) ==
               {:error, [:username, :org_id]}

      assert Recipes.validate_recipe_parameters(@recipe_with_params, @action1.name, %{
               wrong: 1,
               header_id_two: "2"
             }) ==
               {:error, [:url_id, :header_id_one]}
    end
  end

  test "placeholder_regex/0 returns regex for placeholders" do
    assert Recipes.placeholder_regex() == ~r/:([a-zA-Z]{1}([_]*[a-zA-Z]+)*)/
  end
end
