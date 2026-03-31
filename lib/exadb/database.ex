defmodule Exadb.Database do
  @moduledoc """
  Helpers for ArangoDB database administration endpoints.

  This module is useful for provisioning and operational flows, especially in
  multi-tenant systems where databases are created, listed, and removed as part
  of application logic or admin tasks.
  """

  alias Exadb.Api
  alias Exadb.Http

  @doc """
  Lists all databases visible to the authenticated user.
  """
  def get_all(opt \\ []) do
    %{"result" => list} = Http.get!("#{Api.root(opt)}/database")
    list
  end

  @doc """
  Lists the databases a specific user can access and their permission levels.
  """
  def user_dbs(user, opt \\ []) do
    %{"result" => result} = Http.get!("#{Api.root(opt)}/user/#{user}/database")
    result
  end

  @doc """
  Creates a database.
  """
  def new(name, opt \\ []) do
    Http.post!("#{Api.root(opt)}/database", %{name: name})
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
  end

  @doc """
  Drops a database.
  """
  def vaporize(name, opt \\ []) do
    Http.delete!("#{Api.root(opt)}/database/#{name}")
  end
end
