defmodule OpenOwl.PaginationStrategy.NextPageInBody do
  @moduledoc """
  Handles APIs that return the next page cursor in the response body. Furthermore the cursor needs
  to be passed as query parameter.

  ## Example response:
  ```json
  {
    "results": [{"id": 1}, {"id": 2}],
    "pagination": {"next_page": 42"}
  }
  ```

  Use `page_query_param` to define the name of the query parameter.
  You can use the `next_page_response_path` parameter to define the next page field. You can traverse
  into nested structures with the "." syntax (e.g. with `root.deep.deeper`). Here it would be
  `pagination.next_page`.
  """

  use OpenOwl.PaginationStrategy

  alias OpenOwl.Helpers.ApiUtils

  @enforce_keys [:strategy, :next_page_response_path, :page_query_param]
  defstruct strategy: nil, next_page_response_path: nil, page_query_param: nil

  @type t :: %__MODULE__{
          strategy: :next_page_in_body,
          next_page_response_path: String.t(),
          page_query_param: String.t()
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

    next_page = ApiUtils.get_field_via_response_path(body, pagination.next_page_response_path)
    query_param = Keyword.new([{String.to_atom(pagination.page_query_param), next_page}])

    if next_page != nil and next_page != "" do
      case Req.request(req, params: query_param) do
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
