defmodule OpenOwl.ResponseTransformer do
  alias NimbleCSV.RFC4180, as: CSV

  @doc """
  Converts a response that consists of a list of records (maps) of the same
  type to csv.
  """
  def records_to_csv(records) do
    records
    |> records_to_list_with_header()
    |> list_with_header_to_csv()
  end

  def list_with_header_to_csv(list_with_header) when is_list(list_with_header) do
    list_with_header
    |> CSV.dump_to_iodata()
    |> IO.iodata_to_binary()
  end

  @doc false
  def records_to_list_with_header([]) do
    []
  end

  @doc false
  def records_to_list_with_header(map_list) when is_list(map_list) do
    records =
      map_list
      |> Enum.map(fn map ->
        flat_record(map)
      end)

    header = hd(records) |> Map.keys()
    content = Enum.map(records, &Map.values/1)

    [header | content]
  end

  @doc false
  def flat_record(map) do
    flat_record(map, nil)
    |> List.flatten()
    |> Map.new()
  end

  @doc false
  def flat_record(map, prefix) do
    map
    |> Enum.map(fn
      {key, value} when is_map(value) ->
        flat_record(value, [key | [prefix]])

      {key, value} when is_list(value) ->
        if Enum.any?(value, &is_map/1) do
          nil
        else
          {key, value}
        end

      {key, value} ->
        field_name =
          [key | [prefix]]
          |> List.flatten()
          |> Enum.reverse()
          |> Enum.reject(&is_nil/1)
          |> Enum.join(".")

        {field_name, value}
    end)
    |> Enum.reject(&is_nil/1)
  end
end
