defmodule ExAmi.ServerConfigTest do
  use Pavlov.Case, async: true
  import Pavlov.Syntax.Expect  
  alias ExAmi.ServerConfig

  describe "config" do
    let :server_config do
      [asterisk: [connection: {ExAmi.TcpConnection, [host: "127.0.0.1", port: 5038]}, username: "user", secret: "secret"]]
    end

    it "gets connection" do
      expect ServerConfig.get(server_config, :connection) |> elem(0) |> to_eq ExAmi.TcpConnection
    end
    it "gets others" do
      expect ServerConfig.get(server_config, :port) |> to_eq 5038
      expect ServerConfig.get(server_config, :host) |> to_eq "127.0.0.1"
      expect ServerConfig.get(server_config, :username) |> to_eq "user"
      expect ServerConfig.get(server_config, :secret) |> to_eq "secret"
    end
  end

end
