# LiveDelegate

LiveDelegate helps split a Phoenix LiveView into smaller, composable modules
without introducing LiveComponents or changing the normal LiveView lifecycle.

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view
  use LiveDelegate

  alias MyAppWeb.DashboardLive.Projects

  delegate(:projects, Projects)

  def mount(params, session, socket) do
    {:ok, socket |> delegate_mount(params, session)}
  end
end

defmodule MyAppWeb.DashboardLive.Projects do
  use LiveDelegate, path: [:projects]

  def on_mount(_params, _session, socket) do
    socket |> delegate_assign(%{items: []})
  end
end
```

LiveDelegate keeps related concerns together:

- Events are namespaced, such as `"projects:add"`.
- Assigns live under the corresponding path.
- Submodules use familiar LiveView callback signatures and return values.
- A submodule can delegate further work to nested submodules.

See the [`LiveDelegate`](https://hexdocs.pm/live_delegate/LiveDelegate.html)
module documentation for the complete guide.
