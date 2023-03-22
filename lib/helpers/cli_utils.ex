defmodule OpenOwl.Helpers.CliUtils do
  @prefix "OWL_"

  @doc """
  Returns all app environment params downcased and without app prefix.

  iex> get_app_env_params(%{"SHELL" => "/bin/zsh", "DOWL_BLA" => "no", "OWL_USERNAME" => "Oo", "OWL_PASSWORD" => "secret", "OWL_TEAM_ID" => "123"})
  %{username: "Oo", password: "secret", team_id: "123"}

  iex> get_app_env_params(%{"SHELL" => "/bin/zsh", "DOWL_BLA" => "no"})
  %{}

  iex> get_app_env_params(%{})
  %{}
  """
  def get_app_env_params(params \\ System.get_env()) do
    params
    |> Enum.filter(fn
      {@prefix <> _, _value} -> true
      _ -> false
    end)
    |> Enum.map(fn {key, value} -> {normalize_var(key), value} end)
    |> Map.new()
  end

  defp normalize_var(var) do
    var |> String.replace(@prefix, "") |> String.downcase() |> String.to_atom()
  end

  @doc """
  Generates a timebased filename.

  iex> datetime = ~N[2017-11-06 00:23:51.123456]
  iex> timebased_filename("miro.csv", datetime)
  "20171106T002351_miro.csv"

  iex> timebased_filename(nil)
  ** (ArgumentError) filename empty

  iex> timebased_filename("")
  ** (ArgumentError) filename empty
  """
  def timebased_filename(filename, datetime \\ NaiveDateTime.utc_now())
  def timebased_filename(nil, _), do: raise(ArgumentError, "filename empty")
  def timebased_filename("", _), do: raise(ArgumentError, "filename empty")

  def timebased_filename(filename, datetime) do
    now =
      datetime
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601(:basic)

    "#{now}_#{filename}"
  end
end
