defmodule OpenOwl.ApiClient do
  import OpenOwl.Helpers.ApiUtils

  @base_header [
    {"accept-encoding", "gzip"},
    {"accept", "*/*"}
  ]
  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36"

  def do_request(
        cookies,
        session_storage,
        http_method,
        body,
        url,
        headers,
        response_path,
        pagination,
        %{} = placeholder_params,
        placeholders_from_session_storage
      ) do
    cookie_string = filter_relevant_cookies(cookies, url) |> build_cookie_params_string()

    placeholder_params =
      get_params_from_session_storage(session_storage, placeholders_from_session_storage)
      |> Map.merge(placeholder_params)

    # required for local mix run
    Application.ensure_all_started(:telemetry)
    Application.ensure_all_started(:req)

    connect_options =
      if cacertfile = System.get_env("REQ_MINT_CACERTFILE"),
        do: [transport_opts: [cacertfile: cacertfile]],
        else: []

    req =
      Req.new(
        method: http_method,
        body: body,
        url: url,
        headers: build_headers(headers, placeholder_params, cookie_string),
        path_params: placeholder_params,
        connect_options: connect_options,
        user_agent: @user_agent
      )

    case Req.request(req) do
      {:ok, %Req.Response{status: status, body: body}} when status in [200, 201] ->
        if pagination != nil do
          pagination.__struct__.handle_paginated_response(
            req,
            body,
            pagination,
            response_path,
            &extract_data_from_response_body/2
          )
        else
          {:ok, extract_data_from_response_body(body, response_path)}
        end

      {:ok, %Req.Response{status: status, body: body}} when status in [400, 401, 403, 404] ->
        {:http_error, {status, body}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  defp extract_data_from_response_body(body, response_path) do
    get_field_via_response_path(body, response_path)
  end

  defp build_headers(headers, placeholders, cookie_string) do
    req_headers = [{"cookie", cookie_string} | @base_header]

    [headers | req_headers]
    |> List.flatten()
    |> Enum.map(fn {key, value} -> {key, apply_placeholder_params(value, placeholders)} end)
  end
end
