defmodule ExAmi.Example do

  def dial(server_name, channel, extension, context \\ "from-internal", 
        priority \\ "1", variables \\ []) do

    ExAmi.Client.Originate.dial(server_name, channel, 
      {context, extension, priority}, 
      variables, &__MODULE__.response_callback/2)
  end
  def response_callback(response, events) do
    IO.puts "***************************"
    IO.puts ExAmi.Message.format_log(response)
    Enum.each events, fn(event) -> 
      IO.puts ExAmi.Message.format_log(event)
    end
    IO.puts "***************************"
  end
  
end
