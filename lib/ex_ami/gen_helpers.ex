defmodule GenHelpers do

  def next_state({state_data, state_name}) do
    next_state(state_data, state_name)
  end
  def next_state({state_data, state_name}, timeout) do
    next_state(state_data, state_name, timeout)
  end
  def next_state(state_data, state_name) do
    {:next_state,  state_name, state_data}
  end

  def next_state(state_data, state_name, timeout) do
    {:next_state,  state_name, state_data, timeout}
  end

  def reply(state_data, response, state_name) do
    {:reply, response, state_name, state_data}
  end
  
  def reply(state_data, response, state_name, timeout) do
    {:reply, response, state_name, state_data, timeout}
  end
  
end
