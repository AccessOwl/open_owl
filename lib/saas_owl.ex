defmodule OpenOwl do
  @version OpenOwl.MixProject.project() |> Keyword.fetch!(:version)

  def version do
    @version
  end
end
