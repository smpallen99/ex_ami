use Mix.Config

config :ex_ami,
  servers: [
    {:asterisk,
     [
       {:connection,
        {ExAmi.TcpConnection,
         [
           {:host, "127.0.0.1"},
           {:port, 5038}
         ]}},
       {:username, "username"},
       {:secret, "secret"}
     ]}
  ]
