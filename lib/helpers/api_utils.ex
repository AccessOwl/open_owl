defmodule OpenOwl.Helpers.ApiUtils do
  @path_separator "."

  alias OpenOwl.Recipes

  @doc """
  Resolves a response path and get the described string field out of a map. Some APIs have a
  one-element list as root. We handle it by removing this layer.
  If the first argument is a list and the second is nil, the list is returned directly.

  iex> get_field_via_response_path(%{}, nil)
  nil

  iex> get_field_via_response_path(%{}, "a.b")
  nil

  iex> get_field_via_response_path(%{"a" => "hit"}, nil)
  nil

  iex> get_field_via_response_path(%{"a" => "hit", "b" => "nob"}, "a")
  "hit"

  iex> get_field_via_response_path([%{"a" => "hit", "b" => "nob"}], "a")
  "hit"

  iex> get_field_via_response_path(%{"a" => "hit", "b" => "nob"}, "a.a1")
  nil

  iex> get_field_via_response_path(%{"a" => %{"a1" => "hit", "a2" => "noa1"}, "b" => "nob"}, "a.a1")
  "hit"

  iex> get_field_via_response_path(%{"a" => %{"a1" => "hit", "a2" => "hit2"}, "b" => "nob"}, "a.a2")
  "hit2"

  iex> get_field_via_response_path(%{"a" => %{"a1" => "hit", "a2" => %{"a2i" => "hit2", "a2ii" => "noa2ii"}}, "b" => "nob"}, "a.a2.a2i")
  "hit2"

  iex> get_field_via_response_path([%{"a" => "a1"}, %{"a" => "a2"}], nil)
  [%{"a" => "a1"}, %{"a" => "a2"}]

  iex> get_field_via_response_path([%{"a" => "a1"}, %{"a" => "a2"}], "a")
  ** (FunctionClauseError) no function clause matching in OpenOwl.Helpers.ApiUtils.get_field_via_response_path/2
  """
  def get_field_via_response_path(list, nil) when is_list(list), do: list

  def get_field_via_response_path([one], response_path),
    do: get_field_via_response_path(one, response_path)

  def get_field_via_response_path(_map, nil), do: nil

  def get_field_via_response_path(%{} = map, response_path) do
    path = String.split(response_path, @path_separator)
    get_in(map, path)
  rescue
    _ -> nil
  end

  @doc """
  Sets a specific field in a map via the passed path. The (nested) structure must exist, otherwise it
  will raise. Some APIs pass a one-element list as root. Such a structure would be kept.

  iex> flat_map = %{"a" => "a1", "b" => "b1"}
  iex> set_field_via_path(flat_map, nil, "v")
  flat_map
  iex> set_field_via_path(flat_map, "", "v")
  flat_map
  iex> set_field_via_path(flat_map, "c", "v")
  %{"a" => "a1", "b" => "b1", "c" => "v"}
  iex> set_field_via_path(flat_map, "b", "v")
  %{"a" => "a1", "b" => "v"}
  iex> set_field_via_path([flat_map], "b", "v")
  [%{"a" => "a1", "b" => "v"}]

  iex> deep_map = %{"a" => "a1", "b" => "b1", "d" => %{"d1" => "d1v"}}
  iex> set_field_via_path(deep_map, "d.d1", "v")
  %{"a" => "a1", "b" => "b1", "d" => %{"d1" => "v"}}
  iex> set_field_via_path([deep_map], "d.d1", "v")
  [%{"a" => "a1", "b" => "b1", "d" => %{"d1" => "v"}}]
  iex> set_field_via_path(deep_map, "d.d2", "v")
  %{"a" => "a1", "b" => "b1", "d" => %{"d1" => "d1v", "d2" => "v"}}
  iex> set_field_via_path(deep_map, "d.d1.deep", "v")
  ** (FunctionClauseError) no function clause matching in Access.get_and_update/3
  """
  def set_field_via_path(%{} = map, nil, _value), do: map
  def set_field_via_path(%{} = map, "", _value), do: map

  def set_field_via_path([one], field_path, value),
    do: set_field_via_path(one, field_path, value, true)

  def set_field_via_path(%{} = map, field_path, value, list? \\ false) do
    path = String.split(field_path, @path_separator)

    result = put_in(map, path, value)
    if list?, do: [result], else: result
  end

  @doc """
  Filters for cookies of the passed url (domain + subdomain).

  iex> cookie_domain = %{"name" => "session","value" => "123","domain" => "example.com","path" => "/","expires" => -1,"httpOnly" => true,"secure" => true,"sameSite" => "None"}
  iex> cookie_subdomain = %{"name" => "session","value" => "123","domain" => ".example.com","path" => "/","expires" => -1,"httpOnly" => true,"secure" => true,"sameSite" => "None"}
  iex> cookies = [cookie_domain, cookie_subdomain]
  iex> filter_relevant_cookies(cookies, "http://example.com/a?b=2")
  cookies
  iex> filter_relevant_cookies(cookies, "http://s.bla.example.com/a?b=2")
  cookies
  """
  def filter_relevant_cookies(cookies, url) do
    %URI{host: host} = URI.parse(url)

    host =
      host |> String.split(@path_separator) |> Enum.slice(-2..-1) |> Enum.join(@path_separator)

    Enum.filter(cookies, fn cookie ->
      String.contains?(cookie["domain"], host)
    end)
  end

  @doc ~S"""
  Gets the passed params (support paths separated by ".") from session storage. Searches in values
  of all the session storage and merges with maps one level deeper. Also decodes JSON on first level
  if necessary.

  Current implementation is not flexible enough yet to support many use cases. Depending on future
  requirements we will adjust it (including the interface towards recipes).

  iex> get_params_from_session_storage(%{}, [])
  %{}

  iex> payload = %{"adobeid_ims_access_token/ONESIE1/false/AdobeID,ab.manage" => "{\"REAUTH_SCOPE\":\"reauthenticated\",\"client_id\":\"ONESIE1\",\"scope\":\"openid,AdobeID,additional_info.projectedProductContext,read_organizations,read_members,read_countries_regions,additional_info.roles,adobeio_api,read_auth_src_domains,authSources.rwd,bis.read.pi,app_policies.read,app_policies.write,client.read,publisher.read,client.scopes.read,creative_cloud,service_principals.write,aps.read.app_merchandising,aps.eval_licensesforapps,ab.manage,aps.device_activation_mgmt\",\"expire\":\"2023-01-01T13:37:00.342Z\",\"user_id\":\"thisiauser_id\",\"tokenValue\":\"longtoken\",\"sid\":\"thisissid\",\"state\":{},\"fromFragment\":false,\"impersonatorId\":\"\",\"isImpersonatedSession\":false,\"other\":\"{}\",\"pbaSatisfiedPolicies\":[\"MedSecNoEV\",\"LowSec\"]}", "adobeid_ims_profile/ONESIE1/false/AdobeID,ab.manage,additional_info" => "{\"account_type\":\"type2e\",\"utcOffset\":\"null\",\"preferred_languages\":[\"en-us\"],\"displayName\":\"Integration Account\",\"roles\":[{\"principal\":\"LONGID@AdobeOrg:123456\",\"organization\":\"LONGID@AdobeOrg\",\"named_role\":\"org_admin\",\"target\":\"LONGID@AdobeOrg\",\"target_type\":\"TRG_ORG\",\"target_data\":{}}],\"last_name\":\"Account\",\"userId\":\"someuserid.e\",\"authId\":\"someauthid@AdobeID\",\"tags\":[\"agegroup_18plus\"],\"projectedProductContext\":[],\"emailVerified\":\"true\",\"toua\":[{\"touName\":\"creative_cloud\",\"current\":true}],\"phoneNumber\":null,\"countryCode\":\"US\",\"name\":\"Integration Account\",\"mrktPerm\":\"\",\"mrktPermEmail\":null,\"first_name\":\"Integration\",\"email\":\"bruce@wayne.org\"}", "sherlockId" => "sherlockUUID"}
  iex> get_params_from_session_storage(payload, [])
  %{}
  iex> get_params_from_session_storage(payload, ~w(client_id tokenValue notexistent))
  %{client_id: "ONESIE1", tokenValue: "longtoken", notexistent: nil}
  iex> get_params_from_session_storage(payload, ~w(client_id roles.organization))
  %{client_id: "ONESIE1", organization: "LONGID@AdobeOrg"}
  """
  def get_params_from_session_storage(session_storage, params)
      when is_map(session_storage) and is_list(params) do
    result =
      session_storage
      |> Map.values()
      |> Enum.map(fn item ->
        case Jason.decode(item) do
          {:ok, result} -> result
          {:error, _} -> item
        end
      end)
      |> Enum.reduce(%{}, fn
        item, acc when is_map(item) ->
          Map.merge(acc, item)

        # we ignore flat items here for the moment. We might need it later which means refactoring
        # of this approach
        _item, acc ->
          acc
      end)
      |> Enum.map(fn
        {key, []} ->
          {key, []}

        {key, value} when is_list(value) ->
          {key, hd(value)}

        {key, value} ->
          {key, value}
      end)
      |> Map.new()

    Enum.reduce(params, %{}, fn param, acc ->
      Map.put(
        acc,
        get_last_response_path_part(param) |> String.to_atom(),
        get_field_via_response_path(result, param)
      )
    end)
  end

  @doc """
  Returns the last part of a response path that is splitted by #{@path_separator}.

  iex> get_last_response_path_part("a.b.c")
  "c"

  iex> get_last_response_path_part("abc")
  "abc"

  iex> get_last_response_path_part("")
  ""
  """
  def get_last_response_path_part(path) do
    path |> String.split(@path_separator) |> Enum.reverse() |> hd()
  end

  @doc """
  Builds a string properly formatted to send it as cookies header.

  iex> cookie_a = %{"name" => "session","value" => "123","domain" => "example.com","path" => "/","expires" => -1,"httpOnly" => true,"secure" => true,"sameSite" => "None"}
  iex> cookie_b = %{"name" => "bla","value" => "123","domain" => "example.com","path" => "/","expires" => -1,"httpOnly" => true,"secure" => true,"sameSite" => "None"}
  iex> cookies = [cookie_a, cookie_b]
  iex> build_cookie_params_string([cookie_a])
  "session=123"
  iex> build_cookie_params_string(cookies)
  "session=123; bla=123"
  """
  def build_cookie_params_string(cookies) do
    Enum.map_join(cookies, "; ", &(&1["name"] <> "=" <> &1["value"]))
  end

  @doc """
  Replaces placeholder in subject using passed params.

  iex> apply_placeholder_params("cool", %{org: "o1", team_id: 123})
  "cool"

  iex> apply_placeholder_params("cool:org", %{org: "o1", team_id: 123})
  "coolo1"

  iex> apply_placeholder_params("cool_:team_id_:org_", %{org: "o1", team_id: 123})
  "cool_123_o1_"

  iex> apply_placeholder_params("cool_:team_bla_:org_", %{_org: "o1", team_bla_id: 123})
  "cool_:team_bla_:org_"
  """
  def apply_placeholder_params(subject, params) do
    Regex.replace(Recipes.placeholder_regex(), subject, fn whole_match, key ->
      to_string(params[String.to_atom(key)] || whole_match)
    end)
  end
end
