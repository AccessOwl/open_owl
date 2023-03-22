defmodule OpenOwl.PaginationStrategy.PageParamsInUrl do
  @moduledoc """
  Handles APIs that have page params in URL query parameters. By default, it assumes `page`
  is used as parameter. The parameter must be part of the URL in the first request. Subsequent
  requests will increment this parameter.

  The name of the passed `page` param can be defined with `page_query_param`.

  Request loop stops when the page has no data anymore (empty result).
  """
  use OpenOwl.PaginationStrategy

  @enforce_keys [:strategy]
  defstruct strategy: nil, page_query_param: "page"

  @type t :: %__MODULE__{strategy: :page_params_in_url, page_query_param: String.t()}

  @impl true
  def handle_paginated_response(
        %Req.Request{} = req,
        body,
        %__MODULE__{} = pagination,
        response_path,
        data_extraction_fn,
        data_acc \\ []
      ) do
    data = data_extraction_fn.(body, response_path)
    data_acc = data_acc ++ data

    %URI{query: query} = req.url

    query_params_string =
      query
      |> URI.decode_query()
      |> Map.update!(pagination.page_query_param, &(String.to_integer(&1) + 1))
      |> URI.encode_query()

    req =
      update_in(req, [Access.key!(:url), Access.key!(:query)], fn _ -> query_params_string end)

    if data != [] do
      case Req.request(req) do
        {:ok, %Req.Response{status: status, body: body}} when status in [200, 201] ->
          handle_paginated_response(
            req,
            body,
            pagination,
            response_path,
            data_extraction_fn,
            data_acc
          )

        {:ok, %Req.Response{status: status, body: body}} when status in [400, 401, 403, 404] ->
          {:http_error, {status, body}}

        {:error, exception} ->
          {:error, exception}
      end
    else
      {:ok, data_acc}
    end
  end
end
