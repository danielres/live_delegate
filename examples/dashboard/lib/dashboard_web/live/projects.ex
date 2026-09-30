defmodule DashboardWeb.HomeLive.Projects do
  use DashboardWeb, :html
  use LiveDelegate, path: [:projects]

  alias DashboardWeb.HomeLive.Projects.Tools

  delegate(:tools, Tools)

  def on_mount(params, session, socket) do
    data = []

    socket
    |> delegate_assign(%{data: data})
    |> delegate_mount(params, session)
    |> subscribe()
  end

  def handle_event("add", %{"name" => name}, socket) do
    id = System.unique_integer([:positive, :monotonic])
    broadcast({:add, id, name})
    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {id, _} = id |> Integer.parse()
    broadcast({:delete, id})
    {:noreply, socket}
  end

  def handle_info({:add, id, name}, socket) do
    data = socket.assigns.projects.data
    data = [%{id: id, name: name} | data]
    socket = socket |> delegate_assign(:data, data)
    {:noreply, socket}
  end

  def handle_info({:delete, id}, socket) do
    data = socket.assigns.projects.data
    data = data |> Enum.reject(&(&1.id == id))
    socket = socket |> delegate_assign(:data, data)
    {:noreply, socket}
  end

  def handle_info(:delete_all, socket) do
    socket = socket |> delegate_assign(:data, [])
    {:noreply, socket}
  end

  attr :projects, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <form phx-submit={delegate_event("add")} class="flex gap-2">
        <input name="name" class="input" />
        <button class="btn btn-primary" type="submit">Add</button>
      </form>

      <ul class="space-y-1">
        <li
          :for={project <- @projects.data}
          class="bg-base-300 px-4 py-2 rounded"
        >
          <.project project={project} />
        </li>
      </ul>

      <Tools.render :if={@projects.data |> length() > 1} tools={@projects.tools} />
    </div>
    """
  end

  attr :project, :map, required: true

  defp project(assigns) do
    ~H"""
    <div class="flex justify-between items-center">
      <span>{@project.name}</span>

      <button
        type="button"
        class="btn btn-circle btn-xs btn-error btn-soft"
        phx-value-id={@project.id}
        phx-click={delegate_event("delete")}
      >
        <.icon name="hero-x-mark" />
      </button>
    </div>
    """
  end

  defp broadcast(event) do
    Phoenix.PubSub.broadcast(Dashboard.PubSub, "dashboard", {:projects, event})
  end

  defp subscribe(socket) do
    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(Dashboard.PubSub, "dashboard")
    end

    socket
  end
end
