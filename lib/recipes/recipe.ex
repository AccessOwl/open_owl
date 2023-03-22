defmodule OpenOwl.Recipes.Recipe do
  alias OpenOwl.Helpers.StructUtils
  alias OpenOwl.Recipes.Action

  @enforce_keys [
    :login_url,
    :destination_url_pattern,
    :username_selector,
    :password_selector
  ]
  defstruct login_url: nil,
            destination_url_pattern: nil,
            username_selector: nil,
            password_selector: nil,
            actions: []

  @type t :: %__MODULE__{
          login_url: String.t(),
          destination_url_pattern: String.t(),
          username_selector: String.t(),
          password_selector: String.t(),
          actions: [] | [Action.t()]
        }

  def cast(attrs, actions) do
    recipe = StructUtils.to_struct(__MODULE__, attrs)

    %{recipe | actions: Enum.map(actions, &Action.cast/1)}
  end
end
