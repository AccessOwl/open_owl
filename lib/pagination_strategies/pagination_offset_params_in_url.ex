defmodule OpenOwl.PaginationStrategy.OffsetParamsInUrl do
  @moduledoc """
  Handles APIs that have offset params in URL query parameters. By default, it assumes `offset`
  is used as parameter. The parameter must be part of the URL in the first request. Subsequent
  requests will increment this parameter by the value of the `limit` query parameter. The name of
  this parameter can be defined with `limit_query_param` and is `limit` by default.

  The name of the passed `offset` param can be defined with `offset_query_param`.

  Request loop stops when the page has no data anymore (empty result).
  """
  use OpenOwl.PaginationStrategy

  @enforce_keys [:strategy]
  defstruct strategy: nil, offset_query_param: "offset", limit_query_param: "limit"

  @type t :: %__MODULE__{
          strategy: :page_params_in_url,
          offset_query_param: String.t(),
          limit_query_param: String.t()
        }

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
    limit_query_param = pagination.limit_query_param
    %{^limit_query_param => limit} = query_params = URI.decode_query(query)

    query_params_string =
      query_params
      |> Map.update!(
        pagination.offset_query_param,
        &(String.to_integer(&1) + String.to_integer(limit))
      )
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
