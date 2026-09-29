defmodule LiveDelegate do
  @moduledoc """
  Split a Phoenix LiveView into smaller, composable modules.

  ## Parent modules

  A parent module declares its submodules with `delegate/2`:

      defmodule MyAppWeb.DashboardLive do
        use MyAppWeb, :live_view
        use LiveDelegate

        alias MyAppWeb.DashboardLive.Projects

        delegate(:projects, Projects)

        def mount(params, session, socket) do
          {:ok, socket |> delegate_mount(params, session)}
        end
      end

  Submodules are mounted in declaration order.

  ## Submodules

  A submodule declares where it belongs with `path:`:

      defmodule MyAppWeb.DashboardLive.Projects do
        use LiveDelegate, path: [:projects]

        def on_mount(_params, _session, socket) do
          socket |> delegate_assign(%{items: []})
        end

        def handle_event("add", _params, socket) do
          {:noreply, socket}
        end
      end

  The path namespaces its assigns, events, and DOM IDs:

      delegate_assign(socket, value)
      delegate_event("add")       # "projects:add"
      delegate_dom_id("form")     # "projects-form"

  ## Nested submodules

  A module can be both a submodule and a parent:

      defmodule MyAppWeb.DashboardLive.Projects do
        use LiveDelegate, path: [:projects]

        alias MyAppWeb.DashboardLive.Projects.Filters

        delegate(:filters, Filters)

        def on_mount(params, session, socket) do
          socket
          |> delegate_assign(%{items: []})
          |> delegate_mount(params, session)
        end
      end

  The nested module declares its complete path:

      defmodule MyAppWeb.DashboardLive.Projects.Filters do
        use LiveDelegate, path: [:projects, :filters]

        def on_mount(_params, _session, socket) do
          socket |> delegate_assign(%{})
        end
      end

  Its helpers now use the nested namespace:

      delegate_event("change")    # "projects:filters:change"
      delegate_dom_id("panel")    # "projects-filters-panel"

  ## Messages and options

  Use `info:` to route process messages by their first tuple element:

      delegate(:notifications, Notifications,
        events: false,
        info: [:notification_received],
        mount: false
      )

  For example, `{:notification_received, notification}` calls:

      Notifications.handle_info(notification, socket)

  Use `mount: false`, `events: false`, or `info: false` when a submodule does not
  need that responsibility.
  """

  defmacro __using__(opts) do
    {path_imports, path_attribute} = path_configuration(opts)

    imports = [delegate: 2, delegate: 3] |> Keyword.merge(path_imports)

    quote do
      import unquote(__MODULE__), only: unquote(imports)
      unquote(path_attribute)

      Module.register_attribute(__MODULE__, :live_delegates, accumulate: true)
      @before_compile unquote(__MODULE__)
    end
  end

  @doc """
  Assigns a value at the module's configured path.

  Given:

      use LiveDelegate, path: [:projects]

  This:

      socket |> delegate_assign(%{items: []})

  is equivalent to:

      socket |> assign(:projects, %{items: []})

  With a nested path such as `[:projects, :filters]`, the value is assigned at
  `socket.assigns.projects.filters`. The parent assign must already exist.
  """
  defmacro delegate_assign(socket, value) do
    path = configured_path!(__CALLER__)
    assign_expression(socket, Macro.escape(path), value)
  end

  @doc """
  Assigns a value below the module's configured path.

  Given:

      use LiveDelegate, path: [:projects]

  This assigns the form under `socket.assigns.projects.form`:

      socket |> delegate_assign(:form, form)

  A list can be used to update more deeply nested values:

      socket |> delegate_assign([:form, :status], :ready)

  The configured assign and any intermediate maps must already exist.
  """
  defmacro delegate_assign(socket, relative_path, value) do
    path = configured_path!(__CALLER__)

    full_path =
      quote do
        unquote(path) ++ List.wrap(unquote(relative_path))
      end

    assign_expression(socket, full_path, value)
  end

  @doc """
  Builds a DOM ID from the module's configured path.

  Given:

      use LiveDelegate, path: [:projects]

  This produces `id="projects-form"`:

      <.form id={delegate_dom_id("form")} for={@form}>
        ...
      </.form>

  Nested paths are joined with hyphens. With
  `path: [:projects, :filters]`, `delegate_dom_id("panel")` returns
  `"projects-filters-panel"`.
  """
  defmacro delegate_dom_id(value) do
    path = configured_path!(__CALLER__)
    prefix = Enum.join(path, "-")

    quote do
      unquote(prefix) <> "-" <> to_string(unquote(value))
    end
  end

  @doc """
  Builds a LiveView event name from the module's configured path.

  Given:

      use LiveDelegate, path: [:projects]

  This button sends the `"projects:add"` event:

      <button phx-click={delegate_event("add")}>
        Add project
      </button>

  Nested paths produce nested event names. With
  `path: [:projects, :filters]`, `delegate_event("change")` returns
  `"projects:filters:change"`.
  """
  defmacro delegate_event(name) do
    path = configured_path!(__CALLER__)
    prefix = Enum.join(path, ":")

    quote do
      unquote(prefix) <> ":" <> to_string(unquote(name))
    end
  end

  defmacro delegate(name, module_ast, opts \\ []) when is_atom(name) do
    module = Macro.expand(module_ast, __CALLER__)
    events? = Keyword.get(opts, :events, true)
    mount? = Keyword.get(opts, :mount, true)

    unless is_boolean(mount?) do
      raise ArgumentError, "LiveDelegate mount option must be a boolean"
    end

    info_tags =
      case Keyword.get(opts, :info, [name]) do
        false -> []
        tags -> List.wrap(tags)
      end

    quote bind_quoted: [
            name: name,
            module: module,
            events?: events?,
            mount?: mount?,
            info_tags: info_tags
          ] do
      @live_delegates {name, module, mount?, events?, info_tags}
    end
  end

  defmacro __before_compile__(env) do
    delegates =
      env.module
      |> Module.get_attribute(:live_delegates)
      |> Enum.reverse()

    if delegates == [] do
      quote do
      end
    else
      mount_modules =
        for {_name, module, true, _events?, _info_tags} <- delegates do
          module
        end

      event_modules =
        for {name, module, _mount?, true, _info_tags} <- delegates, into: %{} do
          {Atom.to_string(name), module}
        end

      info_modules =
        for {_name, module, _mount?, _events?, info_tags} <- delegates,
            info_tag <- info_tags,
            into: %{} do
          {info_tag, module}
        end

      mount_function =
        if mount_modules == [] do
          quote do
          end
        else
          quote do
            defp delegate_mount(socket, params, session) do
              Enum.reduce(unquote(mount_modules), socket, fn module, socket ->
                module.on_mount(params, session, socket)
              end)
            end
          end
        end

      quote do
        @live_delegate_event_modules unquote(Macro.escape(event_modules))
        @live_delegate_info_modules unquote(Macro.escape(info_modules))

        unquote(mount_function)

        @impl Phoenix.LiveView
        def handle_event(event, payload, socket) do
          [provenance, delegated_event] = String.split(event, ":", parts: 2)
          module = Map.fetch!(@live_delegate_event_modules, provenance)

          module.handle_event(delegated_event, payload, socket)
        end

        @impl Phoenix.LiveView
        def handle_info(message, socket) when is_tuple(message) and tuple_size(message) > 0 do
          [provenance | payload_parts] = Tuple.to_list(message)
          module = Map.fetch!(@live_delegate_info_modules, provenance)

          payload =
            case payload_parts do
              [single_payload] -> single_payload
              multiple_parts -> List.to_tuple(multiple_parts)
            end

          module.handle_info(payload, socket)
        end
      end
    end
  end

  defp path_configuration(opts) do
    case Keyword.fetch(opts, :path) do
      :error ->
        {[],
         quote do
         end}

      {:ok, path} when is_list(path) and path != [] ->
        unless Enum.all?(path, &is_atom/1) do
          raise ArgumentError, "LiveDelegate path must be a non-empty list of atoms"
        end

        {[delegate_assign: 2, delegate_assign: 3, delegate_dom_id: 1, delegate_event: 1],
         quote(do: @live_delegate_path(unquote(path)))}

      {:ok, _path} ->
        raise ArgumentError, "LiveDelegate path must be a non-empty list of atoms"
    end
  end

  defp configured_path!(caller) do
    Module.get_attribute(caller.module, :live_delegate_path) ||
      raise ArgumentError,
            "#{inspect(caller.module)} must configure `use LiveDelegate, path: [...]`"
  end

  defp assign_expression(socket, path, value) do
    quote do
      [assign_name | nested_path] = unquote(path)

      case nested_path do
        [] ->
          Phoenix.Component.assign(unquote(socket), assign_name, unquote(value))

        nested_path ->
          Phoenix.Component.update(unquote(socket), assign_name, fn assign_value ->
            put_in(assign_value, nested_path, unquote(value))
          end)
      end
    end
  end
end
