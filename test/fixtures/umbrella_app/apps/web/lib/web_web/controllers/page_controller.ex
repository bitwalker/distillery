defmodule WebWeb.PageController do
  use WebWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
