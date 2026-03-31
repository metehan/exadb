defmodule Exadb.IntegrationTestHelpers do
  import ExUnit.Assertions

  @default_url "localhost:8529"
  @default_user "root"
  @default_pwd "root"
  @default_db "mix_test"

  def integration_enabled? do
    System.get_env("EXADB_RUN_INTEGRATION") in ["1", "true", "TRUE", "yes", "YES"]
  end

  def admin_opts do
    [
      url: System.get_env("EXADB_TEST_URL", @default_url),
      user: System.get_env("EXADB_TEST_USER", @default_user),
      pwd: System.get_env("EXADB_TEST_PWD", @default_pwd)
    ]
  end

  def setup_database_and_user! do
    admin_opts = admin_opts()
    db_name = System.get_env("EXADB_TEST_DB", @default_db)
    user_pwd = System.get_env("EXADB_TEST_DB_PWD", db_name)

    cleanup_database_and_user(%{admin_opts: admin_opts, db_name: db_name, user_pwd: user_pwd})

    assert %{"result" => true} = Exadb.Database.new_db_and_user(db_name, user_pwd, admin_opts)

    %{
      admin_opts: admin_opts,
      admin_db_opts: Keyword.put(admin_opts, :db, db_name),
      db_name: db_name,
      user_name: db_name,
      user_pwd: user_pwd,
      user_db_opts: [url: admin_opts[:url], user: db_name, pwd: user_pwd, db: db_name]
    }
  end

  def cleanup_database_and_user(%{db_name: db_name, admin_opts: admin_opts}) do
    _ = cleanup_database(%{db_name: db_name, admin_opts: admin_opts})
    _ = cleanup_user(db_name, admin_opts)
    :ok
  end

  def cleanup_database(%{db_name: db_name, admin_opts: admin_opts}) do
    case Exadb.Database.vaporize(db_name, admin_opts) do
      %{"result" => true} -> :ok
      %{"code" => 404} -> :ok
      %{"error" => true, "code" => 404} -> :ok
      %{"error" => true, "errorNum" => 1228} -> :ok
      %{"error" => true} -> :ok
      _other -> :ok
    end
  end

  def cleanup_user(user_name, admin_opts) do
    case Exadb.User.vaporize(user_name, admin_opts) do
      %{"result" => true} -> :ok
      %{"code" => 404} -> :ok
      %{"error" => true, "code" => 404} -> :ok
      %{"error" => true} -> :ok
      _other -> :ok
    end
  end

  def user_db_opts(%{user_db_opts: user_db_opts}, extra \\ []) do
    Keyword.merge(user_db_opts, extra)
  end

  def admin_db_opts(%{admin_db_opts: admin_db_opts}, extra \\ []) do
    Keyword.merge(admin_db_opts, extra)
  end

  def create_database_and_user!(prefix, admin_opts) do
    db_name = unique_name(prefix)
    pwd = db_name

    assert %{"result" => true} = Exadb.Database.new_db_and_user(db_name, pwd, admin_opts)

    %{
      db_name: db_name,
      user_name: db_name,
      user_pwd: pwd,
      admin_opts: admin_opts,
      admin_db_opts: Keyword.put(admin_opts, :db, db_name),
      user_db_opts: [url: admin_opts[:url], user: db_name, pwd: pwd, db: db_name]
    }
  end

  def create_collection!(db_name, admin_opts, prefix \\ "docs") do
    collection = unique_name(prefix)
    db_opts = Keyword.merge(admin_opts, db: db_name, col: collection)

    assert is_map(Exadb.Collection.new_collection(collection, %{}, db_opts))
    assert true = Exadb.Collection.is_there?(collection, db_opts)

    {collection, db_opts}
  end

  def cleanup_collection(collection, db_opts) do
    case Exadb.Collection.is_there?(collection, db_opts) do
      true -> Exadb.Collection.delete(collection, db_opts)
      false -> :ok
      {:error, _reason} = error -> error
    end
  end

  def unique_name(prefix) do
    "#{prefix}_#{System.unique_integer([:positive])}"
  end
end
