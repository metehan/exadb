defmodule Exadb.User do
  @moduledoc """
  Helpers for ArangoDB user management and permission endpoints.

  This module covers the common user administration flows needed by operational
  tooling and multi-tenant systems:

  - create users
  - inspect users
  - update or replace user attributes
  - grant or remove database access
  - delete users

  The term `vaporize` is used for user deletion (rather than `delete`) because
  a user is a runtime entity. `delete` is reserved for schema-level objects
  such as collections and indexes.
  """

  alias Exadb.Api
  alias Exadb.Http
  alias Exadb.Tools

  @doc """
  Creates a user.
  """
  def new(user, opt \\ []) do
    Http.post!("#{Api.root(opt)}/user", user)
    |> Tools.format_api_error()
  end

  @doc """
  Lists users.
  """
  def get_all(opt \\ []) do
    Http.get!("#{Api.root(opt)}/user")
    |> Tools.format_api_error()
  end

  @doc """
  Returns a single user.
  """
  def get(user, opt \\ []) do
    Http.get!("#{Api.root(opt)}/user/#{user}")
    |> Tools.format_api_error()
  end

  @doc """
  Replaces user attributes.
  """
  def replace(user, attrs, opt \\ []) do
    Http.put!("#{Api.root(opt)}/user/#{user}", attrs)
    |> Tools.format_api_error()
  end

  @doc """
  Updates user attributes partially.
  """
  def update(user, attrs, opt \\ []) do
    Http.patch!("#{Api.root(opt)}/user/#{user}", attrs)
    |> Tools.format_api_error()
  end

  @doc """
  Grants a user database access.

  Pass `level: "rw"`, `level: "ro"`, or another supported ArangoDB grant level
  in `opt`.
  """
  def give_access(user, db, opt \\ []) do
    level = Keyword.get(opt, :level, "rw")
    request_opts = Keyword.drop(opt, [:level])

    Http.put!("#{Api.root(request_opts)}/user/#{user}/database/#{db}", %{"grant" => level})
    |> Tools.format_api_error()
  end

  @doc """
  Removes a user's access to a database.
  """
  def remove_access(user, db, opt \\ []) do
    Http.delete!("#{Api.root(opt)}/user/#{user}/database/#{db}")
    |> Tools.format_api_error()
  end

  @doc """
  Deletes a user.
  """
  def vaporize(name, opt \\ []) do
    Http.delete!("#{Api.root(opt)}/user/#{name}")
    |> Tools.format_api_error()
  end
end
