defmodule LiveDelegate do
  @moduledoc """
  Generates LiveView event and message delegation for registered feature modules.

  Delegated events use a `"namespace:event"` name. Delegated process messages
  use tuples whose first element is a registered tag; the remaining elements
  are normalized into one payload passed to `handle_info/2`.

  A module can declare its assign and event path to receive `delegate_assign/2`,
  `delegate_assign/3`, `delegate_dom_id/1`, and `delegate_event/1`:

      use LiveDelegate, path: [:ideas, :tools]

  Delegates are mounted in declaration order. Mounting is enabled by default
  and can be disabled with `mount: false`.
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
  Assigns a value at the path configured by `use LiveDelegate`.
  """
  defmacro delegate_assign(socket, value) do
    path = configured_path!(__CALLER__)
    assign_expression(socket, Macro.escape(path), value)
  end

  @doc """
  Assigns a value below the path configured by `use LiveDelegate`.
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
  Builds a DOM ID from the path configured by `use LiveDelegate`.
  """
  defmacro delegate_dom_id(value) do
    path = configured_path!(__CALLER__)
    prefix = Enum.join(path, "-")

    quote do
      unquote(prefix) <> "-" <> to_string(unquote(value))
    end
  end

  @doc """
  Builds an event name from the path configured by `use LiveDelegate`.
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
