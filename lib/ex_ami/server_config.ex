defmodule ExAmi.ServerConfig do
  require Logger

  def get(server_info, key) do 
    search(server_info, key)
  end

  defp search([], _key), do: nil
  defp search([{_, [{k, v} | _]} | _], key) when k == key,  do: v
  defp search([{_, [{_, v} | tail2]} | tail], key) do
    case search(v, key) do 
      nil -> 
        case search(tail2, key) do 
          nil -> search(tail, key)
          other -> other
        end
      other -> other
    end
  end
  defp search([{k, v} | _], key) when k == key, do: v
  defp search([_ | tail], key), do: search(tail, key)
  defp search({k, v}, key) when k == key, do: v
  defp search({_, [{k, v} | _]}, key) when k == key, do: v
  defp search({_, [{_, v} | tail]}, key) do
    case search(v, key) do
      nil -> search(tail, key)
      other -> other
    end
  end
  defp search(_,_), do: nil

end
