defmodule OpenOwl.PaginationStrategy do
  @type t :: module()
  @type status() :: pos_integer()
  @type body() :: map()
  @type pagination() :: %{atom() => atom() | String.t()}
  @type response_path() :: String.t()

  @doc """
  Casts a map to a typed struct.
  """
  @callback cast(map()) :: %{
              :__struct__ => atom(),
              :strategy => atom(),
              optional(atom()) => any()
            }

  @doc """
  Follows the pagination strategy to accumulate all the data and returns it at once.
  """
  @callback handle_paginated_response(
              %Req.Request{},
              body(),
              pagination(),
              response_path(),
              fun(),
              [map()]
            ) :: {:ok, map()} | {:http_error, {status(), body()}} | {:error, any()}

  defmacro __using__(_options) do
    quote do
      @behaviour OpenOwl.PaginationStrategy

      @impl true
      def cast(attrs) do
        OpenOwl.Helpers.StructUtils.to_struct(__MODULE__, attrs)
      end
    end
  end
end
