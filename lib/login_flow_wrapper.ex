defmodule OpenOwl.LoginFlowWrapper do
  def call_local_cmd(
        slug,
        url,
        destination_url_pattern,
        username_selector,
        password_selector,
        username,
        password,
        pw_debug?
      ) do
    case System.cmd("npm", ["run", "start"],
           env: [
             {"SLUG", slug},
             {"URL", url},
             {"DESTINATION_URL_PATTERN", destination_url_pattern},
             {"USERNAME_SELECTOR", username_selector},
             {"PASSWORD_SELECTOR", password_selector},
             {"USER", username},
             {"PASSWORD", password},
             {"PWDEBUG", if(pw_debug?, do: "1", else: "0")}
           ]
         ) do
      {result, 0} ->
        {:ok, result}

      {result, exit_code} ->
        {:error, %{exit_code: exit_code, result: result}}
    end
  end

  @doc """
  Returns the command to execute for the login flow.

  ## Examples

  iex> get_local_cmd_command("slug", "url", "dest", "usel", "psel", "user", "password")
  ~s(PWDEBUG=1 SLUG=slug URL="url" DESTINATION_URL_PATTERN="dest" USERNAME_SELECTOR="usel" PASSWORD_SELECTOR="psel" USER="user" PASSWORD="password" npm run start)
  """
  def get_local_cmd_command(
        slug,
        url,
        destination_url_pattern,
        username_selector,
        password_selector,
        username,
        password
      ) do
    env = [
      "PWDEBUG=1",
      "SLUG=#{slug}",
      ~s(URL="#{url}"),
      ~s(DESTINATION_URL_PATTERN="#{destination_url_pattern}"),
      ~s(USERNAME_SELECTOR="#{username_selector}"),
      ~s(PASSWORD_SELECTOR="#{password_selector}"),
      ~s(USER="#{username}"),
      ~s(PASSWORD="#{password}")
    ]

    "#{Enum.join(env, " ")} npm run start"
  end
end
