defmodule ExAmi.Logger do
  defmacro __using__(_opts \\ []) do
    quote do
      require Logger
      alias unquote(__MODULE__), as: Logger
    end
  end

  defmacro log(level, message) do
    quote do
      message = unquote(message)
      level = unquote(level)

      if Application.get_env(:ex_ami, :logging) do
        Logger.log(level, message)
      end
    end
  end

  defmacro error(message, metadata \\ []) do
    quote do
      message = unquote(message)
      metadata = unquote(metadata)

      Logger.error(message, metadata)
    end
  end

  defmacro warn(message, metadata \\ []) do
    quote do
      message = unquote(message)
      metadata = unquote(metadata)

      Logger.warn(message, metadata)
    end
  end

  defmacro info(message, metadata \\ []) do
    quote do
      message = unquote(message)
      metadata = unquote(metadata)

      if Application.get_env(:ex_ami, :logging) do
        Logger.info(message, metadata)
      end
    end
  end

  defmacro debug(message, metadata \\ []) do
    quote do
      message = unquote(message)
      metadata = unquote(metadata)

      if Application.get_env(:ex_ami, :logging) do
        Logger.debug(message, metadata)
      end
    end
  end
end
