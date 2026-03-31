defmodule ExadbIntegrationTest do
  use ExUnit.Case, async: false

  import Exadb.IntegrationTestHelpers

  @moduletag integration: true

  setup_all do
    test_db = setup_database_and_user!()
    on_exit(fn -> cleanup_database_and_user(test_db) end)

    {:ok, test_db: test_db}
  end

  test "creates mix_test database and user and exposes them through helper modules", %{
    test_db: test_db
  } do
    assert test_db.db_name == "mix_test"
    assert test_db.user_name == "mix_test"

    assert test_db.db_name in Exadb.Database.get_all(test_db.admin_opts)

    assert %{"user" => "mix_test", "active" => true} =
             Exadb.User.get(test_db.user_name, test_db.admin_opts)

    assert Enum.any?(Exadb.User.get_all(test_db.admin_opts)["result"], fn user ->
             user["user"] == test_db.user_name
           end)

    assert %{"mix_test" => "rw"} = Exadb.Database.user_dbs(test_db.user_name, test_db.admin_opts)
  end

  test "creates, updates, grants, revokes, and deletes users", %{test_db: test_db} do
    user_name = unique_name("user")

    on_exit(fn -> cleanup_user(user_name, test_db.admin_opts) end)

    assert %{"user" => ^user_name, "active" => true} =
             Exadb.User.new(
               %{"user" => user_name, "passwd" => "secret-1", "active" => true},
               test_db.admin_opts
             )

    assert %{"user" => ^user_name, "active" => false} =
             Exadb.User.update(user_name, %{"active" => false}, test_db.admin_opts)

    assert %{"user" => ^user_name, "active" => true} =
             Exadb.User.replace(
               user_name,
               %{"passwd" => "secret-2", "active" => true},
               test_db.admin_opts
             )

    assert %{"code" => 200, "error" => false} =
             Exadb.User.give_access(user_name, test_db.db_name,
               level: "ro",
               url: test_db.admin_opts[:url],
               user: test_db.admin_opts[:user],
               pwd: test_db.admin_opts[:pwd]
             )

    assert %{"result" => permissions} = %{
             "result" => Exadb.Database.user_dbs(user_name, test_db.admin_opts)
           }

    assert permissions[test_db.db_name] == "ro"

    assert %{"code" => 202, "error" => false} =
             Exadb.User.remove_access(user_name, test_db.db_name, test_db.admin_opts)

    refute Map.has_key?(Exadb.Database.user_dbs(user_name, test_db.admin_opts), test_db.db_name)

    assert %{"code" => 202, "error" => false} = Exadb.User.vaporize(user_name, test_db.admin_opts)
  end

  test "covers collection, document, index, and query helpers in mix_test", %{test_db: test_db} do
    db_opts = user_db_opts(test_db)
    collection = unique_name("users")
    renamed_collection = unique_name("members")

    on_exit(fn -> cleanup_collection(renamed_collection, db_opts) end)
    on_exit(fn -> cleanup_collection(collection, db_opts) end)

    assert %{"name" => ^collection, "type" => 2} =
             Exadb.Collection.new_collection(collection, %{}, db_opts)

    assert true = Exadb.Collection.is_there?(collection, db_opts)
    assert %{"name" => ^collection} = Exadb.Collection.get(collection, db_opts)

    assert %{"name" => ^renamed_collection} =
             Exadb.Collection.rename(collection, renamed_collection, db_opts)

    assert true = Exadb.Collection.is_there?(renamed_collection, db_opts)

    all_collections = Exadb.Collection.get_all(Keyword.put(db_opts, :include_system, true))
    assert Enum.any?(all_collections, &(&1["name"] == renamed_collection))

    index =
      Exadb.Index.new(
        renamed_collection,
        %{"type" => "persistent", "fields" => ["email"], "unique" => true},
        Exadb.Api.db(nil, db_opts)
      )

    assert index["type"] == "persistent"
    assert "email" in index["fields"]

    index_list = Exadb.Index.list(renamed_collection, Exadb.Api.db(nil, db_opts))
    assert Enum.any?(index_list["indexes"], &(&1["type"] == "persistent"))

    assert Enum.any?(
             Exadb.Index.clean_list(renamed_collection, Exadb.Api.db(nil, db_opts)),
             &(&1["type"] == "persistent")
           )

    email = "#{unique_name("user")}@example.com"

    created =
      Exadb.Doc.persist(
        %{"email" => email, "active" => false, "roles" => ["reader"]},
        Keyword.put(db_opts, :col, renamed_collection)
      )

    assert %{"_id" => id, "email" => ^email} = created
    assert %{"_id" => ^id} = Exadb.Doc.fetch(id, db_opts)
    assert [[%{"_id" => ^id}]] = Exadb.Doc.fetch_multi([id], db_opts)
    assert email == Exadb.Doc.get_property(id, "email", db_opts)

    assert true =
             Exadb.Doc.is_there?(
               %{"email" => email},
               Keyword.put(db_opts, :col, renamed_collection)
             )

    assert %{"_id" => ^id} =
             Exadb.Doc.push(id, "roles", "writer", db_opts)

    assert %{"_id" => ^id} =
             Exadb.Doc.pop(id, "roles", "reader", db_opts)

    assert %{"_id" => ^id} = Exadb.Doc.switch_on(id, "active", db_opts)
    assert %{"_id" => ^id} = Exadb.Doc.switch_off(id, "active", db_opts)

    extra_records =
      Exadb.Doc.persist_multi(
        [
          %{"email" => "#{unique_name("multi")}@example.com", "initial" => true},
          %{"email" => "#{unique_name("multi")}@example.com", "initial" => false}
        ],
        Keyword.put(db_opts, :col, renamed_collection)
      )

    assert length(extra_records) == 2

    assert %{"_id" => ^id} =
             Exadb.Doc.get_one(
               %{"email" => email},
               Keyword.put(db_opts, :col, renamed_collection)
             )

    assert [_ | _] =
             Exadb.Doc.get(
               %{"active" => false},
               10,
               Keyword.put(db_opts, :col, renamed_collection)
             )

    assert %{"result" => [%{"_id" => ^id}]} =
             Exadb.Query.run(
               "FOR doc IN #{renamed_collection} FILTER doc.email == @email RETURN doc",
               %{email: email},
               db_opts
             )

    first_page =
      Exadb.Query.cursor(
        %{
          query: "FOR doc IN #{renamed_collection} SORT doc.email RETURN doc",
          batchSize: 1
        },
        db_opts
      )

    assert is_map(first_page)
    assert Map.has_key?(first_page, "result")

    streamed_pages =
      Exadb.Query.cursor_stream(
        %{
          query: "FOR doc IN #{renamed_collection} SORT doc.email RETURN doc",
          batchSize: 1
        },
        db_opts
      )
      |> Enum.to_list()

    assert length(streamed_pages) >= 1
    assert Enum.all?(streamed_pages, &is_list(&1["result"]))

    assert {:ok, ^id} = Exadb.Doc.vaporize(%{"_id" => id}, db_opts)
    assert {:ok, :not_found} = Exadb.Doc.vaporize_by_id(id, db_opts)

    refute Exadb.Doc.is_there?(
             %{"email" => email},
             Keyword.put(db_opts, :col, renamed_collection)
           )

    assert %{"code" => 200, "error" => false} =
             Exadb.Index.delete(index["id"], Exadb.Api.db(nil, db_opts))

    assert %{"code" => 200, "error" => false} =
             Exadb.Collection.delete(renamed_collection, db_opts)

    refute Exadb.Collection.is_there?(renamed_collection, db_opts)
  end

  test "covers edge collections and graphs in mix_test", %{test_db: test_db} do
    db_opts = user_db_opts(test_db)
    people = unique_name("people")
    cities = unique_name("cities")
    edges = unique_name("lives_in")
    graph = unique_name("residency")

    on_exit(fn -> Exadb.Graph.delete(graph, Exadb.Api.db(nil, db_opts)) end)
    on_exit(fn -> cleanup_collection(edges, db_opts) end)
    on_exit(fn -> cleanup_collection(cities, db_opts) end)
    on_exit(fn -> cleanup_collection(people, db_opts) end)

    assert %{"name" => ^people} = Exadb.Collection.new_collection(people, %{}, db_opts)
    assert %{"name" => ^cities} = Exadb.Collection.new_collection(cities, %{}, db_opts)
    assert %{"name" => ^edges, "type" => 3} = Exadb.Collection.new_edge(edges, %{}, db_opts)

    assert %{"graph" => %{"name" => ^graph}} =
             Exadb.Graph.new(
               graph,
               [
                 %{
                   collection: edges,
                   from: [people],
                   to: [cities]
                 }
               ],
               [],
               Exadb.Api.db(nil, db_opts)
             )

    assert Enum.any?(
             Exadb.Graph.get_all(Exadb.Api.db(nil, db_opts))["graphs"],
             &(&1["name"] == graph)
           )

    alice = Exadb.Doc.persist(%{"name" => "Alice"}, Keyword.put(db_opts, :col, people))
    berlin = Exadb.Doc.persist(%{"name" => "Berlin"}, Keyword.put(db_opts, :col, cities))
    alice_id = alice["_id"]
    berlin_id = berlin["_id"]

    edge =
      Exadb.Doc.persist(
        %{"_from" => alice_id, "_to" => berlin_id, "kind" => "resident"},
        Keyword.put(db_opts, :col, edges)
      )

    assert %{"result" => [%{"_from" => ^alice_id, "_to" => ^berlin_id}]} =
             Exadb.Query.run(
               "FOR rel IN #{edges} FILTER rel._from == @from RETURN rel",
               %{from: alice_id},
               db_opts
             )

    assert {:ok, _} = Exadb.Doc.vaporize_by_id(edge["_id"], db_opts)
    assert %{"removed" => true} = Exadb.Graph.delete(graph, Exadb.Api.db(nil, db_opts))
  end

  test "copies structure and filtered data with manager helpers", %{test_db: test_db} do
    source_opts = admin_db_opts(test_db)
    source_collection = unique_name("source")
    target = create_database_and_user!("mix_test_copy", test_db.admin_opts)

    on_exit(fn -> cleanup_database_and_user(target) end)
    on_exit(fn -> cleanup_collection(source_collection, source_opts) end)

    assert %{"name" => ^source_collection} =
             Exadb.Collection.new_collection(source_collection, %{}, source_opts)

    assert %{"type" => "persistent"} =
             Exadb.Index.new(
               source_collection,
               %{"type" => "persistent", "fields" => ["tag"], "unique" => false},
               Exadb.Api.db(nil, source_opts)
             )

    Exadb.Doc.persist_multi(
      [
        %{"tag" => "keep", "initial" => true},
        %{"tag" => "drop", "initial" => false}
      ],
      Keyword.put(source_opts, :col, source_collection)
    )

    assert [] = Exadb.Manager.clean_database(Exadb.Api.db(nil, target.admin_db_opts))

    assert [_ | _] =
             Exadb.Manager.copy_database(
               Exadb.Api.db(nil, source_opts),
               Exadb.Api.db(nil, target.admin_db_opts),
               clean_target: true,
               include_data: :initial
             )

    copied_collections = Exadb.Collection.get_all(target.admin_db_opts)
    assert Enum.any?(copied_collections, &(&1["name"] == source_collection))

    copied_indexes =
      Exadb.Index.clean_list(source_collection, Exadb.Api.db(nil, target.admin_db_opts))

    assert Enum.any?(copied_indexes, &(&1["type"] == "persistent"))

    assert [%{"tag" => "keep", "initial" => true}] =
             Exadb.Doc.get(
               %{"tag" => "keep"},
               10,
               Keyword.put(target.admin_db_opts, :col, source_collection)
             )

    assert {:error, :not_found} =
             Exadb.Query.run(
               "FOR doc IN #{source_collection} FILTER doc.tag == @tag RETURN doc",
               %{tag: "drop"},
               target.admin_db_opts
             )
  end
end
