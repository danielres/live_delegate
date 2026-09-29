# LiveDelegate

`LiveDelegate` provides namespaced event, message, mount, assign, and DOM ID
helpers for composing Phoenix LiveViews from smaller feature modules.

## Dispatcher

Register feature modules in the LiveView that owns the Phoenix callbacks:

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view
  use LiveDelegate

  delegate(:messages, MyAppWeb.DashboardLive.Messages)
  delegate(:presence, MyAppWeb.DashboardLive.Presence, info: [:group])

  def mount(params, session, socket) do
    {:ok, socket |> delegate_mount(params, session)}
  end
end
```

Delegates are mounted in declaration order. Set `mount: false`, `events: false`,
or `info: false` to disable the corresponding behavior. The `info` option also
accepts one tag or a list of tags.

`on_mount/3` receives `params`, `session`, and `socket`, and returns the socket
directly. Delegated `handle_event/3` and `handle_info/2` functions return the
usual LiveView callback tuples.

Application-owned `handle_event/3` and `handle_info/2` clauses are evaluated
before LiveDelegate's generated catch-all clauses. Input that reaches those
catch-all clauses must contain a registered event namespace or message tag;
unmatched input fails fast.

## Handler

Configure a path in each feature module:

```elixir
defmodule MyAppWeb.DashboardLive.Messages do
  use LiveDelegate, path: [:messages]

  def on_mount(_params, _session, socket) do
    socket |> delegate_assign(%{form: nil})
  end

  def handle_event("add", payload, socket) do
    # Handles the `"messages:add"` LiveView event.
    {:noreply, socket}
  end
end
```

The configured path provides these helpers:

- `delegate_assign/2` assigns at the configured path.
- `delegate_assign/3` assigns below the configured path.
- `delegate_event/1` builds a colon-separated event name.
- `delegate_dom_id/1` builds a hyphen-separated DOM ID.

Message tuples are dispatched by their first element. Their remaining elements
are normalized before being passed to the handler:

- `{tag}` becomes `{}`.
- `{tag, value}` becomes `value`.
- `{tag, first, second}` becomes `{first, second}`.
