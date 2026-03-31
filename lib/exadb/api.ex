defmodule Exadb.Api do
  @moduledoc """
  Builds ArangoDB API URLs from explicit options or environment variables.

  This module is useful when you want to resolve connection details once and pass
  them through explicitly, especially in scripts, admin tasks, and multi-database
  flows.

  Most higher-level modules can work directly from `:url`, `:user`, `:pwd`, and
  `:db` options, but `Exadb.Api` is helpful whenever you want the resolved URL
  itself.
  """

  @doc """
  Returns the base HTTP URL including credentials.

  Reads from `opt` first and then falls back to `ADB_URL`, `ADB_USER`, and
  `ADB_PWD` environment variables.
  """
  def url(opt \\ []) do
    url = Keyword.get(opt, :url, System.get_env("ADB_URL", "arangodb:8529"))
    user = Keyword.get(opt, :user, System.get_env("ADB_USER", "root"))
    pwd = Keyword.get(opt, :pwd, System.get_env("ADB_PWD", user))

    "http://#{user}:#{pwd}@#{url}"
  end

  @doc """
  Returns the root `/_api` URL for administrative endpoints.
  """
  def root(opt \\ []) do
    url(opt) <> "/_api"
  end

  @doc """
  Returns the database-scoped `/_db/:db/_api` URL.

  If `db` is not passed explicitly, the function uses `:db` from options and then
  falls back to `ADB_DB`.
  """
  def db(db \\ nil, opt \\ []) do
    db =
      if db do
        db
      else
        Keyword.get(opt, :db, System.get_env("ADB_DB", System.get_env("ADB_USER", "default")))
      end

    url(opt) <> "/_db/#{db}/_api"
  end
end
