defmodule LiveDelegate.TestSupport.RootHandler do
  use LiveDelegate, path: [:ideas]

  def assign_value(socket, value), do: socket |> delegate_assign(value)
end
