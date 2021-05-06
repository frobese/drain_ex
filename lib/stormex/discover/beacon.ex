defmodule Stormex.Discover.Beacon do
  defstruct [:addr, :port, :iid, :group, :first_seen, :last_seen]

  def parse_udp_msg(
        {:udp, _socket, addr, _bport,
         <<"DRA", 1, group::binary-size(8), iid::binary-size(8), port::16>>}
      ) do
    {:ok, %__MODULE__{addr: addr, port: port, iid: iid, group: group}}
  end

  def parse_udp_msg(_) do
    {:error, "Can't parse udp_message into a beacon"}
  end

  def parse_udp_msg!(
        {:udp, _socket, addr, _bport,
         <<"DRA", 1, group::binary-size(8), iid::binary-size(8), port::16>>}
      ) do
    %__MODULE__{addr: addr, port: port, iid: iid, group: group}
  end

  def parse_udp_msg!(_) do
    raise(ArgumentError, "Can't parse udp_message into a beacon")
  end

  def locator(group \\ "default") do
    [
      <<"DRA", 1>>,
      format_group(group),
      # iid 0
      <<0::64>>,
      # port 0
      <<0::16>>
    ]
  end

  defp format_group(group) do
    group
    |> to_string()
    |> String.pad_trailing(8, "_")
    |> String.slice(0, 8)
  end
end
