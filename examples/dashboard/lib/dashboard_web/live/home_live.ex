defmodule DashboardWeb.HomeLive do
  use DashboardWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      Hello
    </Layouts.app>
    """
  end
end
