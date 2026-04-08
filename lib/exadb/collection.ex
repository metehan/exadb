defmodule Exadb.Collection do
  @moduledoc """
  Collection helpers for document and edge collections.

  Use this module for schema-level collection operations such as creating,
  renaming, listing, and deleting collections.

  It supports both standard document collections and edge collections.
  """

  alias Exadb.Http
  alias Exadb.Tools

  @doc """
  Creates a document collection.
  """
  def new_collection(name, arango_opts, opt \\ []) do
    new(name, 2, arango_opts, opt)
  end

  @doc """
  Creates an edge collection.
  """
  def new_edge(name, arango_opts, opt \\ []) do
    new(name, 3, arango_opts, opt)
  end

  @doc """
  Creates a collection of the given ArangoDB type.

  Set `opt[:inc]` to create an autoincrement key generator.
  """
  def new(name, type, arango_opts, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    arango_opts =
      if opt[:inc] do
        Map.merge(arango_opts, %{"keyOptions" => %{"type" => "autoincrement"}})
      else
        arango_opts
      end

    Http.post!("#{dblink}/collection", Map.merge(%{name: name, type: type}, arango_opts))
    |> Tools.format_api_error()
  end

  @doc """
  Deletes a collection.

  Use `delete` for schema-level objects (collections, indexes, graphs).
  Use `vaporize` for runtime data records (documents).
  """
  def delete(name, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.delete!("#{dblink}/collection/#{name}")
    |> Tools.format_api_error()
  end

  @doc """
  Renames a collection.
  """
  def rename(old_name, new_name, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.put!("#{dblink}/collection/#{old_name}/rename", %{name: new_name})
    |> Tools.format_api_error()
  end

  @doc """
  Lists collections in the current database.

  By default system collections are filtered out. Pass `include_system: true`
  to keep them in the result. Pass `expanded: true` to return collection
  properties instead of the compact listing.

  Returns `{:ok, list}` on success.
  """
  def get_all(opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)
    include_system = Keyword.get(opt, :include_system, false)

    case Http.get!("#{dblink}/collection") do
      %{"error" => true, "errorMessage" => message} ->
        {:error, message}

      %{"result" => result} ->
        all =
          if include_system do
            result
          else
            Enum.filter(result, fn item -> item["isSystem"] == false end)
          end

        if opt[:expanded] do
          {:ok,
           Enum.map(all, fn item ->
             {:ok, props} = get(item["name"], opt)
             props
           end)}
        else
          {:ok, all}
        end

      unknown ->
        {:error, unknown}
    end
  end

  @doc """
  Returns collection properties for a specific collection.
  """
  def get(collection, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.get!("#{dblink}/collection/#{collection}/properties")
    |> Tools.format_api_error()
  end

  @doc """
  Checks whether a collection exists.
  """
  @spec is_there?(binary(), keyword()) :: boolean() | {:error, binary()}
  def is_there?(name, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    case Http.get!("#{dblink}/collection/#{name}") do
      %{"code" => 404} -> false
      %{"error" => true, "errorMessage" => message} -> {:error, message}
      %{} -> true
    end
  end
end
