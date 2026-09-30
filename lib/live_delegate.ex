defmodule LiveDelegate do
  @moduledoc """
  Split a Phoenix LiveView into smaller, composable modules.

  ## Parent modules

  A parent module declares its submodules with `delegate/2`:

      defmodule MyAppWeb.DashboardLive do
        use MyAppWeb, :live_view
        use LiveDelegate

        alias MyAppWeb.DashboardLive.Projects
        alias MyAppWeb.DashboardLive.Users

        # Mount order follows declaration order: Users, then Projects.
        delegate(:users, Users)
        delegate(:projects, Projects)

        # A single call to delegate_mount/3 mounts the submodules, 
        # calling Users.on_mount/3 then Projects.on_mount/3.
        def mount(params, session, socket) do
          {:ok, socket |> delegate_mount(params, session)}
        end
      end

  ## Mounting delegated submodules

  `delegate_mount/3` runs the `on_mount/3` callback of each delegated submodule
  whose `mount:` option is enabled:

      # In parent module:
      def mount(params, session, socket) do
        {:ok, delegate_mount(socket, params, session)}
      end

      # In submodules:
      def on_mount(params, session, socket) do
        ...
      end

  Delegated submodules are mounted in declaration order. Each submodule receives
  the same `params` and `session`, along with the socket returned by the preceding
  submodule.

  Unlike `c:Phoenix.LiveView.mount/3`, a delegated submodule's `on_mount/3`
  callback must return the updated socket directly, not an `{:ok, socket}` tuple.

  Set `mount: false` when a delegated submodule has no `on_mount/3` callback,
  or when you want to prevent its `on_mount/3` callback from being called:

      delegate(:notifications, Notifications, mount: false)

  If mounting is disabled for every delegated submodule, `delegate_mount/3`
  returns the original socket unchanged.

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
    opts = validate_options!(opts, [:path], __CALLER__)
    {path_imports, path_attribute} = path_configuration(opts, __CALLER__)

    imports = [delegate: 2, delegate: 3, delegate_mount: 3] |> Keyword.merge(path_imports)

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

  @doc """
  Mounts the module's delegated submodules.

  Call this from the parent module's `mount/3` callback:

      def mount(params, session, socket) do
        {:ok, delegate_mount(socket, params, session)}
      end

  Each delegated submodule whose `mount:` option is enabled receives the same
  `params` and `session`. Submodules are called in declaration order, with each
  receiving the socket returned by the preceding submodule. Their `on_mount/3`
  callbacks must return the updated socket directly, not an `{:ok, socket}` tuple.

  Set `mount: false` when a delegated submodule has no `on_mount/3` callback,
  or when you want to prevent its `on_mount/3` callback from being called:

      delegate(:notifications, Notifications, mount: false)

  If mounting is disabled for every delegated submodule, this returns the
  original socket unchanged.
  """
  defmacro delegate_mount(socket, params, session) do
    quote do
      __live_delegate_mount__(unquote(socket), unquote(params), unquote(session))
    end
  end

  defmacro delegate(name, module_ast, opts \\ []) do
    caller = __CALLER__
    validate_delegate_name!(name, caller)

    opts =
      validate_options!(
        opts,
        [events: true, info: [name], mount: true],
        caller
      )

    module = Macro.expand(module_ast, __CALLER__)
    validate_delegate_module!(module, caller)

    events? = Keyword.fetch!(opts, :events)
    mount? = Keyword.fetch!(opts, :mount)

    validate_boolean_option!(:events, events?, caller)
    validate_boolean_option!(:mount, mount?, caller)

    info_tags = validate_info_option!(Keyword.fetch!(opts, :info), caller)

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

    validate_unique!(Enum.map(delegates, &elem(&1, 0)), "delegate names", env)

    validate_unique!(
      for(
        {_name, _module, _mount?, _events?, info_tags} <- delegates,
        info_tag <- info_tags,
        do: info_tag
      ),
      "info tags",
      env
    )

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
        quote do
          defp __live_delegate_mount__(socket, params, session) do
            Enum.reduce(unquote(mount_modules), socket, fn module, socket ->
              module.on_mount(params, session, socket)
            end)
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

  defp path_configuration(opts, caller) do
    case Keyword.fetch(opts, :path) do
      :error ->
        {[],
         quote do
         end}

      {:ok, path} when is_list(path) and path != [] ->
        unless Enum.all?(path, &is_atom/1) do
          configuration_error!(caller, "path must be a non-empty list of atoms")
        end

        {[delegate_assign: 2, delegate_assign: 3, delegate_dom_id: 1, delegate_event: 1],
         quote(do: @live_delegate_path(unquote(path)))}

      {:ok, _path} ->
        configuration_error!(caller, "path must be a non-empty list of atoms")
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

  defp validate_options!(opts, valid_options, caller) do
    Keyword.validate!(opts, valid_options)
  rescue
    error in ArgumentError -> configuration_error!(caller, Exception.message(error))
  end

  defp validate_delegate_name!(name, _caller) when is_atom(name), do: :ok

  defp validate_delegate_name!(name, caller) do
    configuration_error!(caller, "delegate name must be an atom, got: #{inspect(name)}")
  end

  defp validate_delegate_module!(module, _caller) when is_atom(module), do: :ok

  defp validate_delegate_module!(module, caller) do
    configuration_error!(caller, "delegate module must be a module, got: #{inspect(module)}")
  end

  defp validate_boolean_option!(_name, value, _caller) when is_boolean(value), do: :ok

  defp validate_boolean_option!(name, value, caller) do
    configuration_error!(caller, "#{name} must be a boolean, got: #{inspect(value)}")
  end

  defp validate_info_option!(false, _caller), do: []
  defp validate_info_option!(tag, _caller) when is_atom(tag), do: [tag]

  defp validate_info_option!(tags, caller) when is_list(tags) do
    if Enum.all?(tags, &is_atom/1) do
      tags
    else
      configuration_error!(caller, "info must be false, an atom, or a list of atoms")
    end
  end

  defp validate_info_option!(_value, caller) do
    configuration_error!(caller, "info must be false, an atom, or a list of atoms")
  end

  defp validate_unique!(values, label, caller) do
    duplicates =
      values
      |> Enum.frequencies()
      |> Enum.filter(fn {_value, count} -> count > 1 end)
      |> Enum.map(fn {value, _count} -> value end)
      |> Enum.sort()

    if duplicates != [] do
      configuration_error!(caller, "duplicate #{label}: #{inspect(duplicates)}")
    end
  end

  defp configuration_error!(caller, message) do
    raise ArgumentError, "#{inspect(caller.module)}: #{message}"
  end
end
