defmodule OpenOwl.PaginationStrategy.NextCursorInBodyToSendAsJson do
  @moduledoc """
  Handles APIs that return a cursor in the response body. Puts the cursur into a field of the JSON
  request body using `json_body_cursor_path`.
  It needs a boolean flag (`has_next_page_response_path`) to indicate whether the last page was
  reached.

  ## Example response:
  ```json
  {
    "results": [{"id": 1}, {"id": 2}],
    "pagination": {"next_cursor": "abc", "has_next_page": true}
  }
  ```

  You can use the `next_cursor_response_path` parameter to define the field that has the cursor. You
  can traverse into nested structures with the "." syntax (e.g. with `root.deep.deeper`). Here it
  would be `pagination.next_cursor`.
  """

  use OpenOwl.PaginationStrategy

  alias OpenOwl.Helpers.ApiUtils

  @enforce_keys [
    :strategy,
    :next_cursor_response_path,
    :has_next_page_response_path,
    :json_body_cursor_path
  ]
  defstruct strategy: nil,
            next_cursor_response_path: nil,
            has_next_page_response_path: nil,
            json_body_cursor_path: nil

  @type t :: %__MODULE__{
          strategy: :next_cursor_in_body_to_send_as_json,
          next_cursor_response_path: String.t(),
          has_next_page_response_path: String.t(),
          json_body_cursor_path: String.t()
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

    next_cursor = ApiUtils.get_field_via_response_path(body, pagination.next_cursor_response_path)

    new_req_body =
      req.body
      |> Jason.decode!()
      |> ApiUtils.set_field_via_path(pagination.json_body_cursor_path, next_cursor)

    has_next_page? =
      ApiUtils.get_field_via_response_path(body, pagination.has_next_page_response_path)

    if has_next_page? do
      case Req.request(req, json: new_req_body) do
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
