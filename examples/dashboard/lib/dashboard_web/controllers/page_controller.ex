defmodule DashboardWeb.PageController do
  use DashboardWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
