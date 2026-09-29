defmodule LiveDelegateTest do
  use ExUnit.Case, async: true

  alias LiveDelegate.TestSupport.BareHandler
  alias LiveDelegate.TestSupport.Dispatcher
  alias LiveDelegate.TestSupport.MountDispatcher
  alias LiveDelegate.TestSupport.RootHandler

  test "use LiveDelegate does not generate dispatchers without delegates" do
    refute function_exported?(BareHandler, :handle_event, 3)
    refute function_exported?(BareHandler, :handle_info, 2)
  end

  test "builds event names and DOM IDs from the configured path" do
    assert BareHandler.element_id("panel") == "ideas-tools-panel"
    assert BareHandler.event_name("close") == "ideas:tools:close"
  end

  test "assigns a top-level value at the configured path" do
    socket = RootHandler.assign_value(%Phoenix.LiveView.Socket{}, %{})

    assert socket.assigns.ideas == %{}
  end

  test "assigns values at the configured path" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, ideas: %{tools: nil}}
    }

    socket = socket |> BareHandler.assign_value(:start)

    assert socket.assigns.ideas.tools == :start
    assert Map.has_key?(socket.assigns.__changed__, :ideas)
  end

  test "assigns values below the configured path" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, ideas: %{tools: %{}}}
    }

    socket = socket |> BareHandler.assign_relative(:confirmation, :open)

    assert socket.assigns.ideas.tools.confirmation == :open
  end

  test "delegates events by namespace" do
    assert {:event, "ping", %{"value" => 1}, :socket} =
             Dispatcher.handle_event("recipient:ping", %{"value" => 1}, :socket)
  end

  test "delegates info messages by tag" do
    assert {:info, {}, :socket} =
             Dispatcher.handle_info({:source}, :socket)

    assert {:info, :message, :socket} =
             Dispatcher.handle_info({:source, :message}, :socket)

    assert {:info, {:added, :message}, :socket} =
             Dispatcher.handle_info({:source, :added, :message}, :socket)
  end

  test "preserves application-owned event and info clauses" do
    assert {:local_event, %{"value" => 1}, :socket} =
             Dispatcher.handle_event("local", %{"value" => 1}, :socket)

    assert {:local_info, :message, :socket} =
             Dispatcher.handle_info({:local, :message}, :socket)
  end

  test "mounts delegates in declaration order and skips disabled mounts" do
    assert [
             {:first, :params, :session},
             {:second, :params, :session}
           ] = MountDispatcher.mount_delegates([], :params, :session)
  end

  test "rejects unknown options" do
    assert_raise ArgumentError, fn ->
      compile_module("use LiveDelegate, unknown: true")
    end

    assert_raise ArgumentError, fn ->
      compile_module("""
      use LiveDelegate
      delegate(:child, LiveDelegate.TestSupport.Recipient, unknown: true)
      """)
    end
  end

  test "rejects invalid delegate values" do
    declarations = [
      ~s|delegate("child", LiveDelegate.TestSupport.Recipient)|,
      ~s|delegate(:child, "not a module")|,
      ~s|delegate(:child, LiveDelegate.TestSupport.Recipient, events: :yes)|,
      ~s|delegate(:child, LiveDelegate.TestSupport.Recipient, mount: :yes)|,
      ~s|delegate(:child, LiveDelegate.TestSupport.Recipient, info: [:valid, "invalid"])|
    ]

    for declaration <- declarations do
      assert_raise ArgumentError, fn ->
        compile_module("""
        use LiveDelegate
        #{declaration}
        """)
      end
    end
  end

  test "rejects duplicate delegate names and info tags" do
    assert_raise ArgumentError, fn ->
      compile_module("""
      use LiveDelegate
      delegate(:child, LiveDelegate.TestSupport.Recipient, info: false)
      delegate(:child, LiveDelegate.TestSupport.Recipient, info: false)
      """)
    end

    assert_raise ArgumentError, fn ->
      compile_module("""
      use LiveDelegate
      delegate(:first, LiveDelegate.TestSupport.Recipient, info: [:shared])
      delegate(:second, LiveDelegate.TestSupport.Recipient, info: [:shared])
      """)
    end
  end

  defp compile_module(body) do
    module =
      Module.concat(
        LiveDelegate.TestSupport,
        "Dynamic#{System.unique_integer([:positive])}"
      )

    Code.compile_string("""
    defmodule #{inspect(module)} do
      #{body}
    end
    """)
  end
end
