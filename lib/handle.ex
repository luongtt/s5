defmodule S5.Handle do
  require Logger
  alias S5.Handshake

  def start_link(ref, _socket, transport, opts) do
    :gen_statem.start_link(__MODULE__, {ref, transport, opts}, [])
  end

  def init(_args) do
    data = %{
      src_fd: nil,
      dst_fd: nil
    }
    {:ok, :init, data}
  end

  def handle_event(:info, {:handshake, _ref, _transport, socket, _por}, _, data) do
    # client request -> make handshake tcp
    :inet.setopts(socket, [:binary, {:active, true}])
    {:keep_state, %{data | src_fd: socket}}
  end

  def handle_event(:info, {:tcp, socket, bin}, _, %{src_fd: socket} = data) do
    # after handshake -> make S5 connect
    process_hs(Handshake.pretty_bin(bin), data)
  end
  def handle_event(:info, {:tcp, socket, bin}, _, %{dst_fd: socket, src_fd: src_fd} = data) do
    :gen_tcp.send(src_fd, bin)
    {:keep_state, data}
  end

  def handle_event(:info, {:tcp_closed, _}, _state, %{dst_fd: dst_socket, src_fd: c_socket} = data) do
    is_port(c_socket) and :gen_tcp.close(c_socket)
    is_port(dst_socket) and :gen_tcp.close(dst_socket)
    {:keep_state, data}
  end

  def handle_event(ev_type, ev_data, _state, data) do
    Logger.error("DROP #{inspect(ev_type)} / #{inspect(ev_data)}")
    {:keep_state, data}
  end

  def callback_mode, do: :handle_event_function

  def terminate(reason, _state, _data) do
    Logger.error("ERROR=#{inspect(reason)}")
    :ok
  end

  def process_hs({:connect, _bin}, %{src_fd: socket} = data) do
    :gen_tcp.send(socket, Handshake.ans_auth())
    {:keep_state, data}
  end
  def process_hs({:question_auth, _bin}, %{src_fd: socket} = data) do
    :gen_tcp.send(socket, Handshake.ans_auth())
    {:keep_state, data}
  end
  def process_hs({:auth_req, _bin}, %{src_fd: socket} = data) do
    :gen_tcp.send(socket, Handshake.ans_auth(Handshake.user_pass_auth))
    {:keep_state, data}
  end
  def process_hs({:auth, <<_, u_len, username::binary-size(u_len), p_len, passwd::binary-size(p_len)>>},
    %{src_fd: socket} = data) do
    # verify user, passwd here
    Logger.debug("USER=#{username} PASSWD=#{inspect(passwd)}")
    :gen_tcp.send(socket, Handshake.ans_auth())
    {:keep_state, data}
  end
  def process_hs({:associate, <<_, _, _, addr_type, ip1, ip2, ip3, ip4, port::16>>}, data) do
    {:keep_state, dst_connect(addr_type, {ip1, ip2, ip3, ip4}, "#{ip1}.#{ip2}.#{ip3}.#{ip4}", port, data)}
  end
  def process_hs({:associate, <<_, _, _, addr_type, str_len, addr::binary-size(str_len), port::16>>}, data) do
    {:keep_state, dst_connect(addr_type, String.to_charlist(addr), addr, port, data)}
  end
  def process_hs({:forward, bin}, %{dst_fd: dst_socket} = data) when is_port(dst_socket) do
    :gen_tcp.send(dst_socket, bin)
    :inet.setopts(dst_socket, [:binary, {:active, true}])
    {:keep_state, data}
  end
  def process_hs(msg, data) do
    Logger.error("DROP process_hs #{inspect(msg)}")
    {:keep_state, data}
  end

  defp dst_connect(addr_type, addr, f_addr, port, %{src_fd: socket} = data) do
    dst_socket = establish_dest_connection(addr_type, addr, port, data)
    Logger.debug("SRC=#{inspect(:inet.peername(socket))} DEST=#{inspect(f_addr)} PORT=#{inspect(port)}")
    :gen_tcp.send(socket, Handshake.rep_associate(addr_type, f_addr, port))
    %{data | dst_fd: dst_socket, src_fd: socket}
  end

  defp establish_dest_connection(_addr_type, addr, port, _data) do
     {:ok, socket} = :gen_tcp.connect(addr, port, [:binary, active: false])
    socket
  end
end

defmodule S5.Handshake do
  @moduledoc """
    defined packet handshake
  """
  @socks_ver 5
  @no_auth 0
  @reserved 0
  @cmd_connect 1
  @cmd_success 0

  def no_auth, do: 0
  def user_pass_auth, do: 2

  def ans_auth(auth \\ @no_auth) do
    <<@socks_ver, auth>>
  end

  def rep_associate(addr_type, ip, port) do
    <<@socks_ver, @cmd_success, @reserved, addr_type, byte_size(ip), ip::binary, port::16>>
  end

  def pretty_bin(bin) do
    case bin do
      <<@socks_ver, @cmd_connect, 0>> -> {:connect, bin}
      <<@socks_ver, 2, 0, 1>> -> {:question_auth, bin}
      <<@socks_ver, 2, 0, 2>> -> {:question_auth, bin}  # some req by browser req
      <<@socks_ver, 3, 0, _, _>> -> {:auth_req, bin}
      <<1, u_len, _::binary-size(u_len), p_len, _::binary-size(p_len)>> -> {:auth, bin}
      <<@socks_ver, @cmd_connect, @reserved, _::binary>> -> {:associate, bin}
      _ -> {:forward, bin}
    end
  end
end
