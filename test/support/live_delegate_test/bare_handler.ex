defmodule LiveDelegate.TestSupport.BareHandler do
  use LiveDelegate, path: [:ideas, :tools]

  def assign_relative(socket, path, value), do: socket |> delegate_assign(path, value)
  def assign_value(socket, value), do: socket |> delegate_assign(value)
  def element_id(value), do: delegate_dom_id(value)
  def event_name(name), do: delegate_event(name)
end
