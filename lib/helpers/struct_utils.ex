defmodule OpenOwl.Helpers.StructUtils do
  @moduledoc """
  Converts a map with strings, a map with atoms or an existing struct with all
  of the necessary keys into a target struct.
  """

  def to_struct(kind, attrs) do
    struct = struct(kind)

    map_list = Map.to_list(struct)

    Enum.reduce(map_list, struct, fn
      {:__struct__, _}, acc -> acc
      {key, _}, acc -> fetch_value(attrs, key, acc)
    end)
  end

  defp fetch_value(attrs, key, acc) when is_atom(key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> %{acc | key => value}
      :error -> fetch_value(attrs, Atom.to_string(key), acc)
    end
  end

  defp fetch_value(attrs, key, acc) do
    case Map.fetch(attrs, key) do
      # credo:disable-for-next-line
      {:ok, value} -> %{acc | String.to_atom(key) => value}
      :error -> acc
    end
  end
end
