# Elixir Asterisk Management Interface

An Elixir port of the Erlang Asterisk Manager Interface [erlami](https://github.com/marcelog/erlami) project.

This version creates a new AMI connection for each call originated, allowing 
concurrent dialing.

## Configuration

#### Elixir Project

Add the following to `config/config.exs`

```
config :ex_ami, 
  servers: [
    {:asterisk, [
      {:connection, {ExAmi.TcpConnection, [
        {:host, "127.0.0.1"}, {:port, 5038}
      ]}},
      {:username, "username"},
      {:secret, "secret"}
    ]} ]
```

#### Asterisk

Add the username and secret credentials to `manager.conf`

## Installation

Add ex_ami to your `mix.exs` dependencies and start the application:

```
  def application do
    [mod: {MyProject, []},
    applications: [:ex_ami]]
  end
  
  defp deps do
    [{:ex_ami, github: "smpallen99/ex_ami"}]
  end
```

## Example

```
defmodule MyDialer do

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
```

To originate a 3rd party call from extensions 100 to 101:

```
iex> MyDialer.dial(:asterisk, "SIP/100", "101")

```

## License

ex_ami is Copyright (c) 2015 E-MetroTel

The source code is released under the MIT License.

Check [LICENSE](LICENSE) for more information.
