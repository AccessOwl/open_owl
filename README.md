# OpenOwl 🦉

<a href="https://github.com/AccessOwl/open_owl/releases" target="_blank">
    <img src="https://img.shields.io/github/v/release/AccessOwl/open_owl?color=white" alt="Release">
</a>
<a href="https://github.com/AccessOwl/open_owl/actions/workflows/tests.yml" target="_blank">
    <img src="https://img.shields.io/github/actions/workflow/status/AccessOwl/open_owl/tests.yml?branch=main" alt="Build">
</a>

OpenOwl lets you download user lists including user permissions (and other additional data) from various SaaS applications without the need for a public API. This tool is commonly used to check for orphaned user accounts or as preparation for an access review.

This project is made with IT Ops, InfoSec and Compliance teams in mind - no developer experience needed. The [`recipes.yml`](recipes.yml) lists all supported applications. You are welcome to contribute to this project by setting up additional vendor integrations.

## How to run it

Since OpenOwl uses various technologies running it with Docker is recommended. There are additional instructions if you want to run it directly.

### Option 1: Shell Wrapper with [`Docker`](https://docs.docker.com/get-docker/) (Recommended)

The Docker image is built automatically with the first launch.

#### Show all available applications a.k.a recipes

```bash
./owl.sh recipes list
```

#### Step 1. Run `login` action 

Following is an example on how to use it with [`Mezmo`](https://www.mezmo.com/)

Parameters like `OWL_USERNAME` and `OWL_PASSWORD` are passed via the environment variable.

```bash
OWL_USERNAME=someone@acme.com OWL_PASSWORD=abc123 ./owl.sh mezmo login
```

#### Step 2. Run `download_users` action


```bash
./owl.sh mezmo download_users
```

Depending on the application there might be additonal parameters required which will be listed after running the command. If that is the case, add the parameters and re-run the command.


Example for additional parameters:
In [recipes.yml](recipes.yml) you can see that there is a placeholder defined for Mezmo. Placeholders start with a `:` and look like this: `:account_id`. Depending on the recipe they are either passed as parameter or populated from other data (e.g. see Adobe). To pass the `:account_id` parameter, you prefix it with `OWL_` and upcase it. So `:account_id` becomes `OWL_ACCOUNT_ID`.

```bash
OWL_ACCOUNT_ID=YOUR_ACCOUNT_ID ./owl.sh mezmo download_users
```

### Option 2: Docker Compose

Examples:
```bash
docker compose run owl recipes list
docker compose run -e 'OWL_USERNAME=YOUR_USERNAME' -e 'OWL_PASSWORD=YOUR_PASSWORD' owl mezmo login
docker compose run -e 'OWL_ACCOUNT_ID=YOUR_ACCOUNT_ID' owl mezmo download_users
```

### Option 3: Directly 

You can leverage the available [`.tool-versions`](.tool-versions) file to install requirements with [`asdf`](https://asdf-vm.com).

```bash
asdf install
```

Alternatively you can install the required Node, Elixir and Erlang version manually based on the version of the [`.tool-versions`](.tool-versions) file.

Run it with:
```bash
mix run lib/cli.exs <commands>
```

## How does it work?

OpenOwl signs in like a regular user by entering username and password (RPA via Playwright). It then uses the SaaS' internal APIs to request the list of users on your behalf.

This approach only works for SaaS applications with internal APIs. With the rise of single page apps (SPA) (think about React.js, Vue etc.), most applications can be supported. Besides SaaS applications this tool can also be used for internal apps.

## Quick Demo

<a href="http://www.youtube.com/watch?feature=player_embedded&v=0Kz2EwL7xQs" target="_blank">
 <img src="http://img.youtube.com/vi/0Kz2EwL7xQs/0.jpg" alt="Watch the video" width="480" border="0" />
</a>

## Known limitations
1. User Account: The user account needs administrator rights (or a similar permissions that grants access to user lists).
2. Login: Currently only direct logins via username and password are supported. Logins via SSO (Google, Okta, Onelogin,...) will be added in the future.
3. Captchas: Login flows that include captchas are currently not supported.

## How to contribute

[Here](recipes.yml) is the list of available integrations. Open a PR to add further [recipes](recipes.yml), adjust existing ones or extend missing capabilities (like further pagination strategies) to support even more applications.

When all the required capabilities exist, a further integration can take just 30m.

### How to add a new vendor recipe

1. Check that your intended SaaS application has an internal API.
   1. Open the Developer Tools/Inspector of your favourite browser.
   1. Navigate to the page that shows all users.
   1. In your inspector filter by XHR requests and reload the page. When you find some that belong to the same domain like your tool, the application is probably supported.
1. Use the Network tab in the inspector, find the request that includes your list of users with their permissions.
1. Copy the request as `curl`-request and paste it into a tool like [Postman](https://www.postman.com/downloads/). You can import the request by clicking *Import*, selecting *Raw text* and pasting the copied `curl`-request.
1. Execute the request in Postman and remove as many headers and parameters as possible to keep the request clean. Check that the request still works. Add the request to the [`recipes.yml`](recipes.yml).
1. When you have many users in your SaaS account, you will not see all users at once but 10, 50 or 100. Adjust the pagination parameters and try to get all data by traversing through it. Check which [pagination strategy](lib/pagination_strategies/) applies and add it to your added recipe.
1. Open the direct login page of the new vendor and find the right [selector](https://www.cuketest.com/playwright/docs/selectors) for the username and password field. Adjust the [`recipes.yml`](recipes.yml) accordingly.
1. Test that the login flow works properly and the configured action.
1. Open a PR.

## Troubleshooting

### Build Docker image

In case the Shell Wrapper cannot build the Docker image as expected, try the following command to build the image manually:

```bash
docker build -t open_owl-owl:latest .
```

## The history of OpenOwl

Knowing who has access to your SaaS tools is often guesswork at best and manually adding and deleting user accounts is tedious and error prone. The fact that SCIM/SAML are often locked up behind an enterprise-subscription is adding to the frustration. That's why Mathias and Philip decided to build [AccessOwl](https://www.accessowl.io/), a tool to automate SaaS account provisioning for employees for any tool.

OpenOwl is essentially an open-source version of the underlying technology of AccessOwl. It was created out of a discussion that having access to your own teams user data should be a basic right for anybody. No matter whether it's used for audits, to discover orphaned user accounts or run access reviews. That's why we decided to open source a core part of AccessOwl to let anybody read out crucial information out of their SaaS stack.
