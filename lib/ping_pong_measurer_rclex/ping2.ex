defmodule PingPongMeasurerRclex.Ping2 do
  use GenServer

  require Logger

  @ping_max 100
  @message_type 'StdMsgs.Msg.String'
  @ping_topic 'ping_topic'
  @pong_topic 'pong_topic'
  @node_id_prefix 'ping_node'
  @monotonic_time_unit :microsecond

  alias PingPongMeasurerRclex.Utils
  alias PingPongMeasurerRclex.Ping2.Measurer

  defmodule State do
    defstruct context: nil,
              node_id_list: [],
              publishers: [],
              subscribers: [],
              data_directory_path: "",
              from: nil
  end

  def start_link(args_tuple) do
    GenServer.start_link(__MODULE__, args_tuple, name: __MODULE__)
  end

  def init({context, node_counts, data_directory_path}) when is_integer(node_counts) do
    {:ok, node_id_list} = Rclex.ResourceServer.create_nodes(context, @node_id_prefix, node_counts)

    {:ok, publishers} =
      Rclex.Node.create_publishers(node_id_list, @message_type, @ping_topic, :multi)

    {:ok, subscribers} =
      Rclex.Node.create_subscribers(node_id_list, @message_type, @pong_topic, :multi)

    {:ok,
     %State{
       context: context,
       node_id_list: node_id_list,
       publishers: publishers,
       subscribers: subscribers,
       data_directory_path: data_directory_path
     }}
  end

  def get_node_id_list() do
    GenServer.call(__MODULE__, :get_node_id_list)
  end

  def get_publishers do
    GenServer.call(__MODULE__, :get_publishers)
  end

  def publish(publishers, payload) when is_binary(payload) do
    Enum.map(publishers, fn publisher ->
      {node_id, _topic, :pub} = publisher

      Measurer.start_measurement(
        node_id,
        DateTime.utc_now(),
        System.monotonic_time(@monotonic_time_unit)
      )

      ping(node_id, publisher, String.to_charlist(payload))
    end)
  end

  def start_subscribing(from \\ self()) when is_pid(from) do
    GenServer.cast(__MODULE__, {:start_subscribing, from})
  end

  def handle_call(:get_node_id_list, _from, state) do
    {:reply, state.node_id_list, state}
  end

  def handle_call(:get_publishers, _from, state) do
    {:reply, state.publishers, state}
  end

  def handle_cast({:start_subscribing, from}, %State{} = state) do
    for {node_id, index} <- Enum.with_index(state.node_id_list) do
      {_, @ping_topic ++ publisher_index, :pub} = publisher = Enum.at(state.publishers, index)
      {_, @pong_topic ++ subscriber_index, :sub} = subscriber = Enum.at(state.subscribers, index)

      # assert index
      ^publisher_index = subscriber_index

      Rclex.Subscriber.start_subscribing(subscriber, state.context, fn message ->
        message = Rclex.Msg.read(message, @message_type)
        Logger.debug('pong: ' ++ message.data)

        case Measurer.get_ping_counts(node_id) do
          0 ->
            # NOTE: 初回は外部から実行されインクリメントされるので、ここには来ない
            #       ここに来る場合は同一ネットワーク内に Pong が複数起動していないか確認すること
            raise RuntimeError

          @ping_max ->
            Measurer.stop_measurement(node_id, System.monotonic_time(@monotonic_time_unit))
            Logger.debug("#{inspect(Measurer.get_measurement_time(node_id))} msec")
            Measurer.reset_ping_counts(node_id)
            Process.send(from, :finished, _opts = [])

          _ ->
            ping(node_id, publisher, message.data)
        end
      end)
    end

    {:noreply, %State{state | from: from}}
  end

  def ping(node_id, publisher, payload_charlist) when is_list(payload_charlist) do
    Rclex.Publisher.publish([publisher], [Utils.create_payload(payload_charlist)])
    Measurer.increment_ping_counts(node_id)
  end
end
