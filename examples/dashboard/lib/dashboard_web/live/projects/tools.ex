defmodule DashboardWeb.HomeLive.Projects.Tools do
  use DashboardWeb, :html
  use LiveDelegate, path: [:projects, :tools]

  def on_mount(_params, _session, socket) do
    socket |> delegate_assign(%{state: :start})
  end

  def handle_event("start", _, socket) do
    socket = socket |> delegate_assign(%{state: :start})
    {:noreply, socket}
  end

  def handle_event("start_delete_all", _, socket) do
    socket = socket |> delegate_assign(%{state: :start_delete_all})
    {:noreply, socket}
  end

  def handle_event("delete_all", _, socket) do
    broadcast(:delete_all)
    {:noreply, socket}
  end

  attr :projects, :map, required: true

  def render(assigns) do
    ~H"""
    <div class={[
      "grid p-4",
      "border-2 border-warning/20 bg-warning/10",
      "rounded-box"
    ]}>
      <div :if={@tools.state == :start}>
        <button
          type="button"
          class={[
            "btn btn-warning btn-ghost",
            "justify-between w-full"
          ]}
          phx-click={delegate_event("start_delete_all")}
        >
          <span>Delete all</span>
          <.icon name="hero-chevron-right" />
        </button>
      </div>

      <div
        :if={@tools.state == :start_delete_all}
        class="text-center space-y-1"
        phx-click-away={delegate_event("start")}
      >
        <p class="text-warning font-bold">Are you sure?</p>

        <button
          type="button"
          class="btn btn-warning"
          phx-click={delegate_event("delete_all")}
        >
          Delete all
        </button>
      </div>
    </div>
    """
  end

  defp broadcast(event) do
    Phoenix.PubSub.broadcast(Dashboard.PubSub, "dashboard", {:projects, event})
  end
end
