defmodule PingPongMeasurerRclex.Utils do
  def create_payload(charlist) when is_list(charlist) do
    msg = Rclex.Msg.initialize('StdMsgs.Msg.String')

    Rclex.Msg.set(
      msg,
      %Rclex.StdMsgs.Msg.String{data: charlist},
      'StdMsgs.Msg.String'
    )

    msg
  end

  def get_process_name(module, index) do
    :"#{module}_#{index}"
  end
end
