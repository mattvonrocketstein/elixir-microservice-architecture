require Logger

defmodule Functions do
  @doc """
  """
  def to_atom(var) when is_atom(var) or is_bitstring(var) do
    (is_atom(var) && var) || String.to_atom(var)
  end
  def version(module), do: module.__info__(:attributes)[:vsn]
  def noop(), do: :NOOP
  def red(msg), do: "#{IO.ANSI.red()}#{msg}#{IO.ANSI.reset()}"
  def write_red(msg), do: Logger.info(Functions.red(msg))
  def fatal_error(msg) do
    Logger.error(msg)
    System.halt(1)
  end
end
