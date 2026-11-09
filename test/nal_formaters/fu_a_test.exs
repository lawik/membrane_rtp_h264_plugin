defmodule Membrane.RTP.H264.FUTest do
  use ExUnit.Case
  use Bunch

  alias Membrane.RTP.H264.FU
  alias Membrane.Support.Formatters.FUFactory

  describe "Fragmentation Unit parser" do
    test "parses first packet" do
      packet = FUFactory.first()

      assert {:incomplete, _fu} = FU.parse(packet, %FU{})
    end

    test "parses packet sequence" do
      fixtures = FUFactory.get_all_fixtures()

      result =
        fixtures
        |> Enum.reduce(%FU{}, fn elem, acc ->
          FU.parse(elem, acc)
          ~> ({_command, value} -> value)
        end)

      expected_result = FUFactory.glued_fixtures() ~> (<<_header::8, rest::binary>> -> rest)
      assert result == {expected_result, 1}
    end

    test "returns error when first packet is not starting packet" do
      invalid_first_packet = <<0::5, 3::3>>
      assert {:error, :invalid_first_packet} == FU.parse(invalid_first_packet, %FU{})
    end

    test "returns error when header is not valid" do
      assert {:error, :packet_malformed} == FU.parse(<<0::2, 1::1, 1::5>>, %FU{})
    end

    test "returns error when the reassembled NAL unit grows beyond the size limit" do
      payload = :binary.copy(<<0>>, 1024 * 1024)
      first_fragment = <<1::1, 0::2, 1::5>> <> payload
      middle_fragment = <<0::3, 1::5>> <> payload
      {:incomplete, acc} = FU.parse(first_fragment, %FU{})

      # a middle fragment is never the last one, so without a limit the accumulator
      # would keep growing forever
      assert {:error, :nalu_too_large} =
               Enum.reduce_while(1..100, acc, fn _i, acc ->
                 case FU.parse(middle_fragment, acc) do
                   {:incomplete, acc} -> {:cont, acc}
                   other -> {:halt, other}
                 end
               end)
    end
  end
end
