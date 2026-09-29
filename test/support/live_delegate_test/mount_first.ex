defmodule LiveDelegate.TestSupport.MountFirst do
  def on_mount(params, session, mounted) do
    mounted ++ [{:first, params, session}]
  end
end
