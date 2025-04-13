defmodule TunezWeb.HealthController do
  use TunezWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end

