defmodule ApiClientTest do
  use ExUnit.Case, async: true

  alias OpenOwl.ApiClient
  alias OpenOwl.PaginationStrategy.NextCursorInBodyToSendAsJson
  alias OpenOwl.PaginationStrategy.NextPageInBody
  alias OpenOwl.PaginationStrategy.OffsetParamsInUrl
  alias OpenOwl.PaginationStrategy.PageParamsInUrl
  alias OpenOwl.PaginationStrategy.UrlInBody

  # TODO: maybe add bypass to tests transparently
  # https://github.com/wojtekmach/req/issues/137
  setup do
    bypass = Bypass.open()
    [bypass: bypass, url: "http://localhost:#{bypass.port}"]
  end

  defp get_relevant_headers(headers) do
    Enum.reject(headers, &(elem(&1, 0) in ["host", "content-length"]))
  end

  describe "do_request/6" do
    @default_headers [
      {"accept", "*/*"},
      {"accept-encoding", "gzip"},
      {"cookie", ""},
      {"user-agent",
       "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36"}
    ]
    @json_content_type {"content-type", "application/json"}
    @pagination %UrlInBody{strategy: :url_in_body, next_url_response_path: "nextLink"}

    for http_method <- [:get, :post, :put, :patch, :delete] do
      http_method_uppercase = Atom.to_string(http_method) |> String.upcase()

      test "#{http_method_uppercase} returns response body for one page when success", c do
        endpoint = "/do/sth"
        payload = [%{"k" => "v"}]

        Bypass.expect(c.bypass, unquote(http_method_uppercase), endpoint, fn conn ->
          assert get_relevant_headers(conn.req_headers) == @default_headers

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert body == "a=b"

          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => payload}))
        end)

        assert {:ok, payload} ==
                 ApiClient.do_request(
                   [],
                   %{},
                   unquote(http_method),
                   "a=b",
                   c.url <> endpoint,
                   [],
                   "data",
                   @pagination,
                   %{},
                   []
                 )
      end

      test "#{http_method_uppercase} returns response body for one page with deeper response path when success",
           c do
        endpoint = "/do/sth"
        payload = [%{"k" => "v"}]

        Bypass.expect(c.bypass, unquote(http_method_uppercase), endpoint, fn conn ->
          assert get_relevant_headers(conn.req_headers) == @default_headers

          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"deeper" => payload}}))
        end)

        assert {:ok, payload} ==
                 ApiClient.do_request(
                   [],
                   %{},
                   unquote(http_method),
                   nil,
                   c.url <> endpoint,
                   [],
                   "data.deeper",
                   @pagination,
                   %{},
                   []
                 )
      end

      test "#{http_method_uppercase} returns response body for one page without pagination strategy when success",
           c do
        endpoint = "/do/sth"
        payload = [%{"k" => "v"}]

        Bypass.expect(c.bypass, unquote(http_method_uppercase), endpoint, fn conn ->
          assert get_relevant_headers(conn.req_headers) == @default_headers

          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => payload}))
        end)

        assert {:ok, payload} ==
                 ApiClient.do_request(
                   [],
                   %{},
                   unquote(http_method),
                   nil,
                   c.url <> endpoint,
                   [],
                   "data",
                   nil,
                   %{},
                   []
                 )
      end

      test "#{http_method_uppercase} returns response body for multiple pages with url_in_body strategy when success",
           c do
        endpoint1 = "/do/sth/p/1"
        endpoint2 = "/do/sth/p/2"
        payload1 = [%{"k" => "v1"}, %{"k" => "v2"}]
        payload2 = [%{"k" => "v3"}, %{"k" => "v4"}]

        Bypass.expect(c.bypass, unquote(http_method_uppercase), endpoint1, fn conn ->
          assert get_relevant_headers(conn.req_headers) == @default_headers

          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{"data" => payload1, "nextLink" => %{"deeper" => c.url <> endpoint2}})
          )
        end)

        Bypass.expect(c.bypass, unquote(http_method_uppercase), endpoint2, fn conn ->
          assert get_relevant_headers(conn.req_headers) == @default_headers

          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(
            200,
            # TODO: test nextLink = nil
            Jason.encode!(%{"data" => payload2, "nextLink" => %{"deeper" => ""}})
          )
        end)

        assert {:ok, payload1 ++ payload2} ==
                 ApiClient.do_request(
                   [],
                   %{},
                   unquote(http_method),
                   nil,
                   c.url <> endpoint1,
                   [],
                   "data",
                   %UrlInBody{strategy: :url_in_body, next_url_response_path: "nextLink.deeper"},
                   %{},
                   []
                 )
      end

      test "#{http_method_uppercase} returns response body for multiple pages with next_page_in_body strategy when success",
           c do
        endpoint = "/do/sth"
        payload1 = [%{"k" => "v1"}, %{"k" => "v2"}]
        payload2 = [%{"k" => "v3"}, %{"k" => "v4"}]

        Bypass.expect(c.bypass, unquote(http_method_uppercase), endpoint, fn conn ->
          assert get_relevant_headers(conn.req_headers) == @default_headers

          first_page? = not Map.has_key?(conn.query_params, "page")

          if not first_page? do
            assert conn.query_params == %{"page" => "2", "param" => "stays"}
          end

          response =
            if first_page?,
              do: %{"data" => payload1, "pagination" => %{"next_page" => 2}},
              # TODO: test next_page = ""
              else: %{"data" => payload2, "pagination" => %{"next_page" => nil}}

          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(response)
          )
        end)

        assert {:ok, payload1 ++ payload2} ==
                 ApiClient.do_request(
                   [],
                   %{},
                   unquote(http_method),
                   nil,
                   c.url <> endpoint <> "?param=stays",
                   [],
                   "data",
                   %NextPageInBody{
                     strategy: :next_page_in_body,
                     next_page_response_path: "pagination.next_page",
                     page_query_param: "page"
                   },
                   %{},
                   []
                 )
      end

      test "#{http_method_uppercase} returns response body for multiple pages with next_cursor_in_body_populate_as_placeholder strategy when success",
           c do
        sent_body = %{"a" => "a1", "vars" => %{"after" => "", "sth" => "keep"}}
        endpoint = "/do/sth"
        payload1 = [%{"k" => "v1"}, %{"k" => "v2"}]
        payload2 = [%{"k" => "v3"}, %{"k" => "v4"}]

        Bypass.expect(c.bypass, unquote(http_method_uppercase), endpoint, fn conn ->
          req_body =
            with {:ok, body, _conn} <- Plug.Conn.read_body(conn),
                 {:ok, body} <- Jason.decode(body) do
              body
            else
              {:error, _} -> %{}
            end

          first_page? = req_body["vars"]["after"] == ""

          if first_page? do
            assert req_body == sent_body
            assert get_relevant_headers(conn.req_headers) == @default_headers
          else
            assert req_body == put_in(sent_body, ["vars", "after"], "abc")

            assert get_relevant_headers(conn.req_headers) ==
                     List.insert_at(@default_headers, 2, @json_content_type)
          end

          response =
            if first_page?,
              do: %{
                "data" => payload1,
                "pagination" => %{"next_cursor" => "abc", "has_next" => true}
              },
              else: %{
                "data" => payload2,
                "pagination" => %{"next_cursor" => "efg", "has_next" => false}
              }

          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(response)
          )
        end)

        assert {:ok, payload1 ++ payload2} ==
                 ApiClient.do_request(
                   [],
                   %{},
                   unquote(http_method),
                   Jason.encode!(sent_body),
                   c.url <> endpoint,
                   [],
                   "data",
                   %NextCursorInBodyToSendAsJson{
                     strategy: :next_cursor_in_body_to_send_as_json,
                     next_cursor_response_path: "pagination.next_cursor",
                     has_next_page_response_path: "pagination.has_next",
                     json_body_cursor_path: "vars.after"
                   },
                   %{},
                   []
                 )
      end

      test "#{http_method_uppercase} returns response body for multiple pages with page_params_in_url strategy when success",
           c do
        endpoint = "/do/sth"
        payload1 = [%{"k" => "v1"}, %{"k" => "v2"}]
        payload2 = [%{"k" => "v3"}, %{"k" => "v4"}]
        payload3 = []

        Bypass.expect(c.bypass, unquote(http_method_uppercase), endpoint, fn conn ->
          assert get_relevant_headers(conn.req_headers) == @default_headers

          page_param = conn.query_params["page"]
          assert conn.query_params == %{"page" => page_param, "param" => "stays"}

          response =
            case page_param do
              "0" -> payload1
              "1" -> payload2
              "2" -> payload3
            end

          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(response)
          )
        end)

        assert {:ok, payload1 ++ payload2} ==
                 ApiClient.do_request(
                   [],
                   %{},
                   unquote(http_method),
                   nil,
                   c.url <> endpoint <> "?page=0&param=stays",
                   [],
                   nil,
                   %PageParamsInUrl{strategy: :page_params_in_url},
                   %{},
                   []
                 )
      end

      test "#{http_method_uppercase} returns response body for multiple pages with page_params_in_url and custom page_query_param strategy when success",
           c do
        endpoint = "/do/sth"
        payload1 = [%{"k" => "v1"}, %{"k" => "v2"}]
        payload2 = [%{"k" => "v3"}, %{"k" => "v4"}]
        payload3 = []

        Bypass.expect(c.bypass, unquote(http_method_uppercase), endpoint, fn conn ->
          assert get_relevant_headers(conn.req_headers) == @default_headers

          page_param = conn.query_params["p"]
          assert conn.query_params == %{"p" => page_param, "param" => "stays"}

          response =
            case page_param do
              "0" -> payload1
              "1" -> payload2
              "2" -> payload3
            end

          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(response)
          )
        end)

        assert {:ok, payload1 ++ payload2} ==
                 ApiClient.do_request(
                   [],
                   %{},
                   unquote(http_method),
                   nil,
                   c.url <> endpoint <> "?p=0&param=stays",
                   [],
                   nil,
                   %PageParamsInUrl{strategy: :page_params_in_url, page_query_param: "p"},
                   %{},
                   []
                 )
      end

      test "#{http_method_uppercase} returns response body for multiple pages with offset_params_in_url strategy when success",
           c do
        endpoint = "/do/sth"
        payload1 = [%{"k" => "v1"}, %{"k" => "v2"}]
        payload2 = [%{"k" => "v3"}, %{"k" => "v4"}]
        payload3 = []

        Bypass.expect(c.bypass, unquote(http_method_uppercase), endpoint, fn conn ->
          assert get_relevant_headers(conn.req_headers) == @default_headers

          offset_param = conn.query_params["offset"]
          limit_param = conn.query_params["limit"]

          assert conn.query_params == %{
                   "offset" => offset_param,
                   "limit" => limit_param,
                   "param" => "stays"
                 }

          response =
            case offset_param do
              "0" -> payload1
              "2" -> payload2
              "4" -> payload3
            end

          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(response)
          )
        end)

        assert {:ok, payload1 ++ payload2} ==
                 ApiClient.do_request(
                   [],
                   %{},
                   unquote(http_method),
                   nil,
                   c.url <> endpoint <> "?offset=0&limit=2&param=stays",
                   [],
                   nil,
                   %OffsetParamsInUrl{strategy: :offset_params_in_url},
                   %{},
                   []
                 )
      end

      test "#{http_method_uppercase} returns response body for multiple pages with offset_params_in_url and custom params strategy when success",
           c do
        endpoint = "/do/sth"
        payload1 = [%{"k" => "v1"}, %{"k" => "v2"}]
        payload2 = [%{"k" => "v3"}, %{"k" => "v4"}]
        payload3 = []

        Bypass.expect(c.bypass, unquote(http_method_uppercase), endpoint, fn conn ->
          assert get_relevant_headers(conn.req_headers) == @default_headers

          offset_param = conn.query_params["start_offset"]
          limit_param = conn.query_params["size"]

          assert conn.query_params == %{
                   "start_offset" => offset_param,
                   "size" => limit_param,
                   "param" => "stays"
                 }

          response =
            case offset_param do
              "0" -> payload1
              "2" -> payload2
              "4" -> payload3
            end

          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(response)
          )
        end)

        assert {:ok, payload1 ++ payload2} ==
                 ApiClient.do_request(
                   [],
                   %{},
                   unquote(http_method),
                   nil,
                   c.url <> endpoint <> "?start_offset=0&size=2&param=stays",
                   [],
                   nil,
                   %OffsetParamsInUrl{
                     strategy: :offset_params_in_url,
                     offset_query_param: "start_offset",
                     limit_query_param: "size"
                   },
                   %{},
                   []
                 )
      end
    end

    test "replaces placeholder in passed URL and headers properly", c do
      endpoint_prefix = "/do/sth:not/"
      payload = [%{"k" => "v"}]

      Bypass.expect(c.bypass, "GET", "#{endpoint_prefix}123", fn conn ->
        assert get_relevant_headers(conn.req_headers) ==
                 @default_headers ++
                   [{"x-dynamic", "pre_123-post"}, {"x-not", ":there"}, {"x-static", "Blub 1"}]

        Plug.Conn.put_resp_header(conn, "content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => payload}))
      end)

      assert {:ok, payload} ==
               ApiClient.do_request(
                 [],
                 %{},
                 :get,
                 nil,
                 c.url <> endpoint_prefix <> ":team_id",
                 [
                   {"X-Dynamic", "pre_:team_id-post"},
                   {"X-Not", ":there"},
                   {"X-Static", "Blub 1"}
                 ],
                 "data",
                 @pagination,
                 %{team_id: "123"},
                 []
               )
    end

    test "uses session_storage to populate new placeholders and replaces it in passed URL and headers properly",
         c do
      endpoint_prefix = "/do/sth:not/"
      payload = [%{"k" => "v"}]

      Bypass.expect(c.bypass, "GET", "#{endpoint_prefix}123/v2", fn conn ->
        assert get_relevant_headers(conn.req_headers) ==
                 @default_headers ++
                   [
                     {"x-passed", "pre_123-post"},
                     {"x-populated", "pre_v3b"},
                     {"x-static", "Blub 1"}
                   ]

        Plug.Conn.put_resp_header(conn, "content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => payload}))
      end)

      assert {:ok, payload} ==
               ApiClient.do_request(
                 [],
                 %{
                   "whatever_1" => Jason.encode!(%{"kone" => "v1", "ktwo" => "v2"}),
                   "whatever_2" =>
                     Jason.encode!(%{"kthree" => [%{"kthree_a" => "v3a", "kthree_b" => "v3b"}]}),
                   "none" => "nope"
                 },
                 :get,
                 nil,
                 c.url <> endpoint_prefix <> ":team_id/:ktwo",
                 [
                   {"X-passed", "pre_:team_id-post"},
                   {"X-populated", "pre_:kthree_b"},
                   {"X-Static", "Blub 1"}
                 ],
                 "data",
                 @pagination,
                 %{team_id: "123"},
                 ["ktwo", "kthree.kthree_b"]
               )
    end

    for status <- [400, 401, 403, 404] do
      test "returns http_error when status is #{status}", c do
        endpoint = "/do/sth"
        payload = %{"error" => "oops"}

        Bypass.expect(c.bypass, "GET", endpoint, fn conn ->
          Plug.Conn.put_resp_header(conn, "content-type", "application/json")
          |> Plug.Conn.send_resp(unquote(status), Jason.encode!(payload))
        end)

        response =
          ApiClient.do_request(
            [],
            %{},
            :get,
            nil,
            c.url <> endpoint,
            [],
            "data",
            @pagination,
            %{},
            []
          )

        assert {:http_error, {unquote(status), ^payload}} = response
      end
    end
  end
end
