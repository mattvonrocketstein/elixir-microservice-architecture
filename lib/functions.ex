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
  def report(header, msg\\nil) do
    out = if (msg), do: Functions.red("#{header}: "), else: ""
    msg = if (msg), do: msg, else: header
    out = out <> "#{inspect msg}"
    Logger.info(out)
  end
  def fatal_error(msg) do
    Logger.error(msg)
    System.halt(1)
  end
end
