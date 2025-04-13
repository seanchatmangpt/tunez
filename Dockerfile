FROM debian:bookworm-slim

ARG MIX_ENV=dev
ENV MIX_ENV=${MIX_ENV}
ENV LANG=C.UTF-8
ENV TERM=xterm

# Install build essentials
RUN apt-get update && apt-get install -y \
    git curl wget build-essential libssl-dev libncurses5-dev \
    ca-certificates unzip && \
    rm -rf /var/lib/apt/lists/*

# Install asdf
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
ENV PATH="/root/.asdf/bin:/root/.asdf/shims:$PATH"

# Copy asdf config and install tools
WORKDIR /app
COPY .tool-versions .tool-versions
RUN asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git && \
    asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git && \
    asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git && \
    asdf install

# Install Hex/Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Cache dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

# Copy app source
COPY assets assets
COPY config config
COPY lib lib
COPY priv priv

# Compile assets and application
RUN mix assets.setup && \
    mix assets.deploy && \
    mix compile

# Expose Phoenix port
EXPOSE 4000

# Run Phoenix Server
CMD ["mix", "phx.server"]
