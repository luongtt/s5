defmodule S5 do
  @moduledoc """
  Documentation for `S5`.
  """

  use Application
  require Logger

  def start(_type, _args) do
    :rand.seed(:exs64, :os.timestamp())
    :logger.add_handlers(:s5)
    ret = S5.Sup.start_link()
    IO.inspect(ret)
    Logger.info("READY!")
    ret
  end
end


defmodule S5.Sup do
  @moduledoc """
    S5 Sup
  """
  require Logger

  use Supervisor
  @name :s5_sup

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def init(_args) do
    port = System.get_env("LISTEN_PORT", "62621") |> String.to_integer()
    socks5 =
      :ranch.child_spec(
        :proxy_server,
        :ranch_tcp,
        %{
          num_acceptors: 2,
          max_connections: :infinity,
          ssl: true,
          socket_opts: [
            {:port, port}
          ]
        },
        S5.Handle,
        []
      )
    Logger.info("LISTEN_PORT: #{inspect(port)}")
    Supervisor.init([socks5], strategy: :one_for_one)
  end
end
