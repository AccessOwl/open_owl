defmodule OpenOwl.Recipes do
  @recipe_file_name "recipes.yml"
  @external_resource Path.join(File.cwd!(), @recipe_file_name)
  @placeholder_regex ~r/:([a-zA-Z]{1}([_]*[a-zA-Z]+)*)/

  alias OpenOwl.Recipes.Recipe
  alias OpenOwl.Recipes.Action

  def load_recipes(rel_path \\ @recipe_file_name) do
    path = Path.join(File.cwd!(), rel_path)

    case YamlElixir.read_from_file(path) do
      {:ok, data} -> {:ok, parse_yaml_data(data)}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_recipe(recipes, slug) when is_binary(slug) do
    get_recipe(recipes, String.to_atom(slug))
  end

  def get_recipe(recipes, slug) do
    Map.get(recipes, slug)
  end

  def get_action_for_name(actions, name) do
    Enum.find(actions, &(&1.name == name))
  end

  @doc false
  def get_required_parameters_for_recipe(
        %Recipe{login_url: login_url, destination_url_pattern: destination_url_pattern},
        "login"
      ) do
    [:username, :password] ++ get_parameters([login_url, destination_url_pattern])
  end

  @doc false
  def get_required_parameters_for_recipe(%Recipe{actions: actions}, action_name) do
    with %Action{url: url, headers: headers} <- get_action_for_name(actions, action_name) do
      get_parameters([url | get_header_values(headers)])
    else
      nil -> []
    end
  end

  defp get_parameters(strings) do
    strings
    |> Enum.reduce([], fn string, acc ->
      matches = Regex.scan(@placeholder_regex, string, capture: :first)
      [matches | acc]
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.map(&atomize_placeholder_string/1)
  end

  defp atomize_placeholder_string(placeholder) do
    ":" <> name = placeholder
    String.to_atom(name)
  end

  defp get_header_values(headers) do
    Enum.map(headers, fn {_, value} -> value end)
  end

  def validate_recipe_parameters(%Recipe{} = recipe, action, %{} = parameter_map) do
    parameters = Map.keys(parameter_map)
    required_parameters = get_required_parameters_for_recipe(recipe, action)
    missing_parameters = required_parameters -- parameters

    if missing_parameters == [] do
      {:ok, parameter_map}
    else
      {:error, missing_parameters}
    end
  end

  @doc false
  def placeholder_regex() do
    @placeholder_regex
  end

  defp parse_yaml_data(%{} = data) do
    Enum.reduce(data, %{}, fn {key, value}, acc ->
      Map.put(acc, String.to_atom(key), OpenOwl.Recipes.Recipe.cast(value, value["actions"]))
    end)
  end
end
