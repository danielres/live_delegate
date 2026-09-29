defmodule LiveDelegate.TestSupport.MountSecond do
  def on_mount(params, session, mounted) do
    mounted ++ [{:second, params, session}]
  end
end
