defmodule Exadb.Query do
  @moduledoc """
  Helpers for running AQL queries and consuming cursors.

  Use this module when the work is better expressed in AQL than through direct
  document helpers.

  `Exadb.Query.run/3` is the simplest entry point for one-off queries.
  `cursor/2` and `cursor_stream/2` are better fits for multi-page result sets.
  """

  alias Exadb.Http
  alias Exadb.Tools

  @doc """
  Runs an AQL query and returns the decoded response.

  Returns `{:error, :not_found}` for empty result sets and `{:error, message}`
  when ArangoDB reports a query error.
  """
  def run(query, vars, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    case Http.post!("#{dblink}/cursor", %{query: query, bindVars: vars}) do
      %{"error" => true, "errorMessage" => message} -> {:error, message}
      %{"result" => []} -> {:error, :not_found}
      %{"result" => _result} = results -> results
      unknown -> {:error, unknown}
    end
  end

  @doc """
  Interacts with ArangoDB cursors.

  Accepts either:

  - a binary AQL query
  - a map used to create a cursor
  - a previous cursor response with `"id"` and `"hasMore"`
  """
  def cursor(query, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    case query do
      %{"hasMore" => false} ->
        {:error, :no_more_result}

      {:error, _reason} = error ->
        error

      %{"id" => id, "hasMore" => true} ->
        try do
          Http.put!("#{dblink}/cursor/#{id}")
          |> cursor_result()
        rescue
          error in HTTPoison.Error -> {:error, error}
          other -> {:error, other}
        end

      binary when is_binary(binary) ->
        cursor(%{query: binary}, opt)

      map when is_map(map) ->
        try do
          Http.post!("#{dblink}/cursor", map)
          |> cursor_result()
        rescue
          error in HTTPoison.Error -> {:error, error}
          other -> {:error, other}
        end
    end
  end

  @doc """
  Streams cursor pages until ArangoDB reports there are no more results.
  """
  def cursor_stream(query, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Stream.resource(
      fn -> query end,
      fn current ->
        case cursor(current, dblink: dblink) do
          {:error, reason} -> {:halt, reason}
          result -> {[result], result}
        end
      end,
      fn _last -> :ok end
    )
  end

  defp cursor_result(result) do
    case result do
      %{"result" => _result} -> result
      %{"error" => true, "errorMessage" => message} -> {:error, message}
      %{"code" => 404} -> {:error, :not_found}
      unknown -> {:error, unknown}
    end
  end
end
