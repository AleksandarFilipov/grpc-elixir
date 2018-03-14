defmodule Interop.Server do
  @moduledoc false
  use GRPC.Server, service: Grpc.Testing.TestService.Service

  def empty_call(_, _stream) do
    Grpc.Testing.Empty.new()
  end

  def unary_call(req, stream) do
    headers = GRPC.Stream.get_headers(stream)
    stream = case headers["x-grpc-test-echo-initial"] do
      nil -> stream
      val ->
        GRPC.Server.send_headers(stream, %{"x-grpc-test-echo-initial" => val})
    end
    stream = case headers["x-grpc-test-echo-trailing-bin"] do
      nil -> stream
      val ->
        GRPC.Server.set_trailers(stream, %{"x-grpc-test-echo-trailing-bin" => val})
    end
    payload = Grpc.Testing.Payload.new(body: String.duplicate("0", req.response_size))
    {Grpc.Testing.SimpleResponse.new(payload: payload), stream}
  end

  def streaming_input_call(req_enum, _stream) do
    size = Enum.reduce(req_enum, 0, fn(req, acc) -> acc + byte_size(req.payload.body) end)
    Grpc.Testing.StreamingInputCallResponse.new(aggregated_payload_size: size)
  end

  def streaming_output_call(req, stream0) do
    req.response_parameters
    |> Enum.map(&Grpc.Testing.Payload.new(body: String.duplicate("0", &1.size)))
    |> Enum.map(&Grpc.Testing.StreamingOutputCallResponse.new(payload: &1))
    |> Enum.reduce(stream0, &GRPC.Server.stream_send(&2, &1))
  end

  def full_duplex_call(req_enum, stream0) do
    Enum.reduce(req_enum, stream0, fn(req, stream) ->
      size = List.first(req.response_parameters).size
      payload = Grpc.Testing.Payload.new(body: String.duplicate("0", size))
      res = Grpc.Testing.StreamingOutputCallResponse.new(payload: payload)
      GRPC.Server.stream_send(stream, res)
    end)
  end
end
