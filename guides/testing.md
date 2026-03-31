# Testing

The standalone package has two test layers:

- request-level tests with `Bypass`
- opt-in integration tests against a real ArangoDB instance

The request-level suite stays fast and deterministic while still validating:

- request paths
- HTTP verbs
- JSON request bodies
- response decoding
- option handling such as `:db`, `:col`, and `:level`

## Run the default suite

```bash
mix deps.get
mix test
```

Integration tests are tagged with `:integration` and excluded by default.

## Run integration tests

Use either ExUnit's include flag or the environment flag:

```bash
mix test --include integration
EXADB_RUN_INTEGRATION=1 mix test
```

The integration helper reads dedicated test environment variables:

- `EXADB_TEST_DB` defaults to `mix_test`
- `EXADB_TEST_URL` defaults to `localhost:8529`
- `EXADB_TEST_USER` defaults to `root`
- `EXADB_TEST_PWD` defaults to `root`

By default, the integration suite recreates the `mix_test` database and matching `mix_test` user before the run and removes them afterwards.

If `EXADB_TEST_DB` is set, that database name is used instead and the matching user name is derived from it.

Examples:

```bash
mix test --include integration
EXADB_TEST_DB=my_test_db mix test --include integration
EXADB_TEST_URL=localhost:8529 EXADB_TEST_USER=root EXADB_TEST_PWD=root mix test --include integration
```

## Run docs locally

```bash
mix docs
```
