defmodule OpenOwl.CLI do
  alias OpenOwl.Recipes
  alias OpenOwl.Recipes.Recipe
  alias OpenOwl.Recipes.Action
  alias OpenOwl.ResponseTransformer
  alias OpenOwl.LoginFlowWrapper
  import OpenOwl.Helpers.ApiUtils, only: [apply_placeholder_params: 2]
  import OpenOwl.Helpers.CliUtils

  @owl_cli_name "./owl.sh"
  @env_prefix "OWL_"
  @auth_cache_folder "auth_cache"

  # escript
  def main(args) do
    args
    |> parse_args()
    |> process_params()
  end

  # direct call via mix run
  def main() do
    System.argv()
    |> parse_args()
    |> process_params()
  end

  defp parse_args(args) do
    {flags, commands, _} =
      OptionParser.parse(args,
        strict: [debug: :boolean, pwdebug: :boolean, output: :string, help: :boolean]
      )

    {commands, flags}
  end

  defp process_params({["recipes", "list"], _}) do
    IO.puts("Listing recipes with actions and parameters...\n")

    recipes = load_recipes()
    trailing_padding = get_trailing_padding(recipes)

    recipes
    |> Enum.each(fn {title, %Recipe{actions: actions} = recipe} ->
      title =
        title
        |> Atom.to_string()
        |> String.capitalize()
        |> then(&"#{&1}: ")
        |> String.pad_trailing(trailing_padding)

      login_parameters =
        recipe
        |> Recipes.get_required_parameters_for_recipe("login")
        |> parameter_list_as_env()
        |> maybe_in_brackets()

      IO.puts(title <> "login #{login_parameters}")

      Enum.each(actions, fn %Action{} = action ->
        parameters =
          recipe
          |> Recipes.get_required_parameters_for_recipe(action.name)
          |> parameter_list_as_env()
          |> maybe_in_brackets()

        IO.puts(String.pad_trailing("", trailing_padding) <> "#{action.name} #{parameters}")
      end)
    end)
  end

  defp process_params({[vendor, "login"], flags}) do
    recipes = load_recipes()
    # TODO: until we pull that out from a config or sth
    app_env_params = get_app_env_params()

    with %Recipe{} = recipe <- Recipes.get_recipe(recipes, vendor),
         {:ok, %{username: username, password: password}} <-
           Recipes.validate_recipe_parameters(recipe, "login", app_env_params) do
      IO.puts("Starting #{vendor}: login...")

      if Keyword.get(flags, :debug, false) do
        IO.puts("DEBUG=true\n")

        LoginFlowWrapper.get_local_cmd_command(
          vendor,
          apply_placeholder_params(recipe.login_url, app_env_params),
          apply_placeholder_params(recipe.destination_url_pattern, app_env_params),
          recipe.username_selector,
          recipe.password_selector,
          username,
          password
        )
        |> IO.puts()
      else
        case LoginFlowWrapper.call_local_cmd(
               vendor,
               apply_placeholder_params(recipe.login_url, app_env_params),
               apply_placeholder_params(recipe.destination_url_pattern, app_env_params),
               recipe.username_selector,
               recipe.password_selector,
               username,
               password,
               Keyword.get(flags, :pwdebug, false)
             ) do
          {:ok, _} ->
            IO.puts("... authentication info saved")
            IO.puts("DONE")

          {:error, %{exit_code: exit_code, result: result}} ->
            write_error("#{exit_code}: #{inspect(result)}")
        end
      end
    else
      {:error, missing_parameters} ->
        write_error("missing parameters: #{parameter_list_as_env(missing_parameters)}")

      nil ->
        write_error("vendor #{vendor} not found")
    end
  end

  defp process_params({[vendor, action_name], flags}) when vendor != "recipes" do
    recipes = load_recipes()
    app_env_params = get_app_env_params()

    IO.puts("Starting #{vendor}: #{action_name}...")
    cookies_path = Path.join([File.cwd!(), @auth_cache_folder, "#{vendor}_cookies.json"])

    session_storage_path =
      Path.join([File.cwd!(), @auth_cache_folder, "#{vendor}_session_storage.json"])

    session_storage =
      case File.read(session_storage_path) do
        {:ok, data} -> Jason.decode!(data)
        {:error, _} -> %{}
      end

    with {:ok, cookie_binary_json} <- File.read(cookies_path),
         {:ok, cookies} <- Jason.decode(cookie_binary_json),
         %Recipe{actions: actions} = recipe <- Recipes.get_recipe(recipes, vendor),
         %Action{} = action <- Recipes.get_action_for_name(actions, action_name),
         {:ok, _} <- Recipes.validate_recipe_parameters(recipe, action_name, app_env_params) do
      IO.puts(
        "... #{action.http_method}-request #{apply_placeholder_params(action.url, app_env_params)}..."
      )

      case OpenOwl.ApiClient.do_request(
             cookies,
             session_storage,
             action.http_method,
             action.body,
             action.url,
             action.headers,
             action.response_path,
             action.pagination,
             app_env_params,
             action.populate_placeholders_from_session_storage
           ) do
        {:ok, response} ->
          output_flag = Keyword.get(flags, :output)

          filename =
            if output_flag == nil, do: timebased_filename("#{vendor}.csv"), else: output_flag

          path = Path.join([File.cwd!(), "results", filename])
          content = ResponseTransformer.records_to_csv(response)
          File.write!(path, content)
          IO.puts("... wrote results to #{filename}")
          IO.puts("DONE")

        {:http_error, {status, body}} ->
          write_error("HTTP (#{status}): #{inspect(body)}")

        {:error, reason} ->
          write_error("#{inspect(reason)}")
      end
    else
      nil ->
        write_error("Vendor #{vendor} or action #{action_name} not found")

      {:error, missing_parameters} when is_list(missing_parameters) ->
        write_error("missing parameters: #{parameter_list_as_env(missing_parameters)}")

      {:error, %Jason.DecodeError{} = reason} ->
        write_error("#{inspect(reason)}")

      {:error, reason} ->
        write_error(
          "Authentication cookies file #{cookies_path} could not be loaded: #{inspect(reason)}"
        )
    end
  end

  defp process_params(_), do: print_help()

  defp print_help() do
    version = OpenOwl.version()

    IO.puts("OpenOwl v#{version}\n")
    IO.puts("Usage:")

    IO.puts(
      "           #{@owl_cli_name} recipes list              - Show list of recipes with their actions"
    )

    IO.puts(
      "[env_vars] #{@owl_cli_name} <vendor> login            - Authenticate and get required authentication"
    )

    IO.puts(
      "[env_vars] #{@owl_cli_name} <vendor> <action> [flags] - Triggers defined action of recipes.yml\n"
    )

    IO.puts("Env vars:")
    IO.puts("  Some commands need set environment variables. You can prepend commands with them.")
    IO.puts("  For instance OWL_USERNAME=user #{@owl_cli_name} <vendor> login\n")

    IO.puts("Flags:")
    IO.puts("  --output - Set a custom output filename. Otherwise a timebased filename is used.")
    IO.puts("  --help   - Print this help message")
  end

  defp load_recipes() do
    case Recipes.load_recipes() do
      {:ok, recipes} ->
        recipes

      {:error, reason} ->
        raise "File could not be loaded: #{inspect(reason)}"
    end
  end

  defp get_trailing_padding(%{} = recipes) do
    Enum.map(recipes, fn {title, _} -> "#{title}: " end)
    |> get_trailing_padding()
  end

  defp get_trailing_padding(title_list) when is_list(title_list) do
    title_list
    |> Enum.max(fn left, right -> String.length(left) >= String.length(right) end)
    |> String.length()
  end

  defp parameter_list_as_env(list) do
    list
    |> Enum.map(&to_string/1)
    |> Enum.map(&"#{@env_prefix}#{String.upcase(&1)}")
    |> Enum.join(", ")
  end

  defp maybe_in_brackets(""), do: ""

  defp maybe_in_brackets(string) do
    "(#{string})"
  end

  defp write_error(msg) do
    IO.puts("ERROR: #{msg}")
    System.halt(1)
  end
end

OpenOwl.CLI.main()
