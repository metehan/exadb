defmodule Exadb.Graph do
  @moduledoc """
  Helpers for ArangoDB graph endpoints.

  Use this module to manage named graphs backed by existing vertex and edge
  collections.
  """

  alias Exadb.Http
  alias Exadb.Tools

  @doc """
  Creates a named graph.
  """
  def new(name, edge_definitions, orphan_collections, dblink) do
    Http.post!("#{dblink}/gharial", %{
      name: name,
      edgeDefinitions: edge_definitions,
      orphanCollections: orphan_collections
    })
    |> Tools.format_api_error()
  end

  @doc """
  Deletes a named graph.
  """
  def delete(name, dblink) do
    Http.delete!("#{dblink}/gharial/#{name}")
  end

  @doc """
  Lists named graphs.
  """
  def get_all(dblink) do
    Http.get!("#{dblink}/gharial")
  end
end
