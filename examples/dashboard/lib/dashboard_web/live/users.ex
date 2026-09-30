defmodule DashboardWeb.HomeLive.Users do
  use DashboardWeb, :html
  use LiveDelegate, path: [:users]

  def on_mount(_params, _session, socket) do
    data = [
      %{id: 1, name: "Tom"},
      %{id: 2, name: "Dave"}
    ]

    socket |> delegate_assign(%{data: data})
  end

  attr :users, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <ul class="flex gap-2">
        <li
          :for={user <- @users.data}
          class="bg-base-300 px-4 py-2 rounded flex gap-2 items-center"
        >
          <.icon name="hero-user-mini" class="opacity-50" />
          {user.name}
        </li>
      </ul>
    </div>
    """
  end
end
