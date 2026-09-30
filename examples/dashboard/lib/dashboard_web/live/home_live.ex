defmodule DashboardWeb.HomeLive do
  use DashboardWeb, :live_view
  use LiveDelegate
  alias DashboardWeb.HomeLive.Projects

  delegate(:projects, Projects)

  @impl true
  def mount(params, session, socket) do
    socket = socket |> delegate_mount(params, session)
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.section>
        <:title>Projects</:title>
        <Projects.render projects={@projects} />
      </.section>
    </Layouts.app>
    """
  end

  slot :title

  defp section(assigns) do
    ~H"""
    <section class="bg-base-200 p-4 rounded-box space-y-2">
      <h3 class="font-semibold">
        {render_slot(@title)}
      </h3>

      {render_slot(@inner_block)}
    </section>
    """
  end
end
