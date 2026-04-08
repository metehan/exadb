defmodule Exadb.Database do
  @moduledoc """
  Helpers for ArangoDB database administration endpoints.

  This module is useful for provisioning and operational flows, especially in
  multi-tenant systems where databases are created, listed, and removed as part
  of application logic or admin tasks.

  The term `vaporize` is used for deletion here (rather than `delete`) because
  a database is a runtime resource that may or may not exist. `delete` is
  reserved for schema-level objects such as collections and indexes.
  """

  alias Exadb.Api
  alias Exadb.Http
  alias Exadb.Tools

  @doc """
  Lists all databases visible to the authenticated user.
  """
  def get_all(opt \\ []) do
    case Http.get!("#{Api.root(opt)}/database") do
      %{"error" => true, "errorMessage" => message} -> {:error, message}
      %{"result" => list} -> {:ok, list}
      unknown -> {:error, unknown}
    end
  end

  @doc """
  Lists the databases a specific user can access and their permission levels.
  """
  def user_dbs(user, opt \\ []) do
    case Http.get!("#{Api.root(opt)}/user/#{user}/database") do
      %{"error" => true, "errorMessage" => message} -> {:error, message}
      %{"result" => result} -> {:ok, result}
      unknown -> {:error, unknown}
    end
  end

  @doc """
  Creates a database.
  """
  def new(name, opt \\ []) do
    Http.post!("#{Api.root(opt)}/database", %{name: name})
    |> Tools.format_api_error()
  end

  @doc """
  Creates a database and an initial user for it.

  The new user uses the database name as its username.
  """
  def new_db_and_user(name, pass, opt \\ []) do
    Http.post!("#{Api.root(opt)}/database", %{
      name: name,
      users: [
        %{
          username: name,
          passwd: pass,
          active: true
        }
      ]
    })
    |> Tools.format_api_error()
  end

  @doc """
  Drops a database.
  """
  def vaporize(name, opt \\ []) do
    Http.delete!("#{Api.root(opt)}/database/#{name}")
    |> Tools.format_api_error()
  end
end
