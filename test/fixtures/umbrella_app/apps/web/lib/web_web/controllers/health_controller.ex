defmodule WebWeb.HealthController do
  use WebWeb, :controller

  def index(conn, _params) do
    json conn, %{status: :ok}
  end
end
