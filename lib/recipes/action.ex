defmodule OpenOwl.Recipes.Action do
  alias OpenOwl.Helpers.StructUtils

  @enforce_keys [:name, :http_method, :url]
  defstruct name: nil,
            http_method: nil,
            body: nil,
            url: nil,
            headers: [],
            response_path: nil,
            pagination: nil,
            populate_placeholders_from_session_storage: []

  @type t :: %__MODULE__{
          name: String.t(),
          http_method: :get | :post | :put | :patch | :delete,
          body: String.t(),
          url: String.t(),
          headers: [{String.t(), String.t()}],
          response_path: String.t() | nil,
          pagination: OpenOwl.PaginationStrategy.t() | nil,
          populate_placeholders_from_session_storage: [String.t()] | nil
        }

  def cast(attrs) do
    http_method =
      case attrs do
        %{http_method: http_method} -> http_method
        %{"http_method" => http_method} -> http_method
      end

    headers =
      case attrs do
        %{headers: headers} -> headers
        %{"headers" => headers} -> headers
        _ -> []
      end
      |> Enum.map(fn header -> Map.to_list(header) |> hd() end)

    {pagination_strategy, pagination_attrs} =
      case attrs do
        %{pagination: pagination} ->
          {pagination[:strategy], pagination}

        %{"pagination" => pagination} ->
          {pagination["strategy"], pagination}

        _ ->
          {nil, nil}
      end

    pagination_mod = modulize(pagination_strategy)

    action =
      StructUtils.to_struct(__MODULE__, attrs)
      |> Map.put(:http_method, http_method_to_atom(http_method))
      |> Map.put(:headers, headers)

    if pagination_mod != nil,
      do: Map.put(action, :pagination, apply(pagination_mod, :cast, [pagination_attrs])),
      else: action
  end

  defp http_method_to_atom(http_method) do
    http_method |> String.downcase() |> String.to_atom()
  end

  defp modulize(nil), do: nil

  defp modulize(underscored_string) do
    underscored_string
    |> String.split("_")
    |> Enum.map_join(&String.capitalize/1)
    |> then(&Module.concat(OpenOwl.PaginationStrategy, &1))
  end
end
