defmodule Exadb.Manager do
  @moduledoc """
  Higher-level helpers for copying database structure and data.

  This module is aimed at operational workflows such as:

  - copying one database structure into another
  - creating tenant databases from templates
  - copying collections with or without data
  - keeping indexes aligned across databases

  It builds on `Exadb.Collection`, `Exadb.Index`, and `Exadb.Query` to provide
  higher-level orchestration helpers.
  """

  alias Exadb.Collection
  alias Exadb.Index
  alias Exadb.Query

  @doc """
  Deletes all collections in a database.
  """
  def clean_database(dblink) do
    {:ok, collections} = Collection.get_all(dblink: dblink)

    collections
    |> Enum.map(& &1["name"])
    |> Enum.map(&Collection.delete(&1, dblink: dblink))
  end

  @doc """
  Copies database structure and optionally data from one database to another.

  Supported options include:

  - `:clean_target` to delete existing target collections first
  - `:include_data` with `:all`, `:initial`, or another value to skip data copy
  """
  def copy_database(dblink_from, dblink_to, opt \\ []) do
    if Keyword.get(opt, :clean_target), do: clean_database(dblink_to)

    {:ok, collections} = Collection.get_all(dblink: dblink_from, expanded: true)
    collection_names = Enum.map(collections, & &1["name"])

    collections
    |> Enum.map(fn collection ->
      Collection.new(
        collection["name"],
        collection["type"],
        %{"keyOptions" => collection["keyOptions"]},
        dblink: dblink_to
      )
    end)

    collection_names
    |> Enum.map(fn name ->
      {:ok, indexes} = Index.clean_list(name, dblink: dblink_from)
      %{collection: name, indexes: indexes}
    end)
    |> Enum.reject(&(&1.indexes == []))
    |> Enum.map(&Index.new(&1.collection, &1.indexes, dblink: dblink_to))

    case Keyword.get(opt, :include_data, :all) do
      :initial ->
        collection_names
        |> Enum.map(fn collection_name ->
          copy_collection_data_filtered(%{
            filter: "r.initial == true",
            from_collection: collection_name,
            to_collection: collection_name,
            from_dblink: dblink_from,
            to_dblink: dblink_to
          })
        end)

      :all ->
        collection_names
        |> Enum.map(fn collection_name ->
          copy_collection_data(%{
            from_collection: collection_name,
            to_collection: collection_name,
            from_dblink: dblink_from,
            to_dblink: dblink_to
          })
        end)

      _ ->
        [:ok]
    end
  end

  @doc """
  Copies data from a collection using a custom filter.
  """
  def copy_collection_data_filtered(
        %{from_collection: from_collection, filter: filter} = req,
        opt \\ []
      ) do
    copy_query(Map.put(req, :query, "FOR r IN #{from_collection} FILTER #{filter} RETURN r"), opt)
  end

  @doc """
  Copies all data from one collection into another.
  """
  def copy_collection_data(%{from_collection: from_collection} = req, opt \\ []) do
    copy_query(Map.put(req, :query, "FOR r IN #{from_collection} RETURN r"), opt)
  end

  @doc """
  Copies query results into a target collection.

  This is the lower-level helper used by the higher-level copy functions.
  """
  def copy_query(
        %{
          query: query,
          to_collection: to_collection,
          from_dblink: from_dblink,
          to_dblink: to_dblink
        },
        opt \\ []
      ) do
    if Keyword.get(opt, :clean_target, true) do
      Query.run("FOR r IN #{to_collection} REMOVE r IN #{to_collection}", %{}, dblink: to_dblink)
    end

    %{query: query}
    |> Query.cursor_stream(dblink: from_dblink)
    |> Stream.filter(&(&1["result"] != []))
    |> Stream.map(&copy_query_insert(&1, to_collection, to_dblink))
    |> Stream.run()
  end

  defp copy_query_insert(data, to_collection, to_db_link) do
    Query.run(
      "FOR record IN @records INSERT record INTO #{to_collection} RETURN NEW",
      %{records: data["result"]},
      dblink: to_db_link
    )
  end
end
