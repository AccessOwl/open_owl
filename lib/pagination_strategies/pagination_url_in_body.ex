defmodule OpenOwl.PaginationStrategy.UrlInBody do
  @moduledoc """
  Handles APIs that return a URL in the response body where the next page can be fetched.

  ## Example response:
  ```json
  {
    "results": [{"id": 1}, {"id": 2}],
    "nextLink": "https://api.example.com/?nextLink=456"
  }
  ```

  You can use the `next_url_response_path` parameter to define the field that has the URL. You can
  traverse into nested structures with the "." syntax (e.g. with `root.deep.deeper`). Here it would
  be just `nextLink`.
  """

  use OpenOwl.PaginationStrategy

  alias OpenOwl.Helpers.ApiUtils

  @enforce_keys [:strategy, :next_url_response_path]
  defstruct strategy: nil, next_url_response_path: nil

  @type t :: %__MODULE__{
          strategy: :url_in_body,
          next_url_response_path: String.t()
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

    next_url = ApiUtils.get_field_via_response_path(body, pagination.next_url_response_path)

    if next_url != nil and next_url != "" do
      case Req.request(req, url: next_url) do
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
