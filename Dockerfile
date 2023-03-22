###
### First Stage - Building the Elixir app as escript
###
FROM hexpm/elixir:1.14.3-erlang-23.2.6-alpine-3.16.0 AS build

# install build dependencies
RUN apk add --no-cache build-base git

# prepare build dir
WORKDIR /app

# extend hex timeout
ENV HEX_HTTP_TIMEOUT=20

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy over the mix.exs and mix.lock files to load the dependencies. If those
# files don't change, then we don't keep re-fetching and rebuilding the deps.
COPY mix.exs mix.lock ./

RUN mix deps.get && \
    mix deps.compile && \
    mkdir priv && \
    # because of https://github.com/elixir-mint/castore/issues/35
    cp _build/dev/lib/castore/priv/cacerts.pem priv/cacerts.pem

COPY lib lib

RUN mix compile && \
    mix escript.build

###
### Second Stage - Setup the Runtime Environment
###

FROM node:16-bullseye-slim AS app

ENV LANG=C.UTF-8

# Install Firefox dependencies + tools
RUN sh -c 'echo "deb http://ftp.us.debian.org/debian bullseye main non-free" >> /etc/apt/sources.list.d/fonts.list' && \
    DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends erlang && \
    #  clean apt cache
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN npm config --global set update-notifier false
ENV PLAYWRIGHT_BROWSERS_PATH=/playwright
ENV REQ_MINT_CACERTFILE=/app/bin/cacerts.pem

COPY package*.json ./
RUN PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --include=dev --omit=optional --audit=false --progress=false --loglevel=error
RUN npm_config_ignore_scripts=1 npx playwright install-deps firefox && \
    npx playwright install firefox

COPY ts_src ts_src
COPY tsconfig.json ./
RUN npm run build

COPY --from=build /app/owl ./bin/owl
COPY --from=build /app/priv/cacerts.pem ./bin/cacerts.pem

RUN mkdir -p /app/results

ENV HOME=/app
ENV MIX_ENV=dev

ENTRYPOINT ["./bin/owl"]
