#!/usr/bin/env bats

setup() {
  # shellcheck source=tests/helpers/common.bash
  source "$BATS_TEST_DIRNAME/helpers/common.bash"
  load_lib
}

@test "parse_list: empty input produces no output" {
  run parse_list ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "parse_list: comma-separated codes" {
  run parse_list "zh_Hans,en"
  [ "$status" -eq 0 ]
  [ "$output" = $'zh_Hans\nen' ]
}

@test "parse_list: bracketed list with spaces" {
  run parse_list "[zh_Hans, en]"
  [ "$status" -eq 0 ]
  [ "$output" = $'zh_Hans\nen' ]
}

@test "parse_list: trailing comma ignored" {
  run parse_list "en,"
  [ "$status" -eq 0 ]
  [ "$output" = "en" ]
}

@test "parse_extensions: bracketed extensions" {
  run parse_extensions "[.adoc, .md]"
  [ "$status" -eq 0 ]
  [ "$output" = $'.adoc\n.md' ]
}

@test "parse_extensions: JSON-style quoted extensions" {
  run parse_extensions '[".adoc",".md"]'
  [ "$status" -eq 0 ]
  [ "$output" = $'.adoc\n.md' ]
}

@test "parse_extensions: bare extension gets dot prefix" {
  run parse_extensions "adoc"
  [ "$status" -eq 0 ]
  [ "$output" = ".adoc" ]
}

@test "parse_extensions: empty input produces no output" {
  run parse_extensions ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "is_valid_lang_code: accepts common BCP 47 codes" {
  is_valid_lang_code "en"
  is_valid_lang_code "zh_Hans"
  is_valid_lang_code "pt_BR"
}

@test "is_valid_lang_code: rejects invalid codes" {
  ! is_valid_lang_code ""
  ! is_valid_lang_code "en US"
  ! is_valid_lang_code "zh/Hans"
  ! is_valid_lang_code "a"
}

@test "get_doc_paths: single-library repo emits doc" {
  # shellcheck source=tests/helpers/mock_gh.bash
  source "$BATS_TEST_DIRNAME/helpers/mock_gh.bash"
  install_mock_gh
  export MOCK_LIBRARIES_FIXTURE="$FIXTURES_DIR/libraries-single.json"

  run get_doc_paths "algorithm" "develop"
  [ "$status" -eq 0 ]
  [ "$output" = "doc" ]

  restore_mock_gh
}

@test "get_doc_paths: multi-library repo emits per-key doc paths" {
  # shellcheck source=tests/helpers/mock_gh.bash
  source "$BATS_TEST_DIRNAME/helpers/mock_gh.bash"
  install_mock_gh
  export MOCK_LIBRARIES_FIXTURE="$FIXTURES_DIR/libraries-multi.json"

  run get_doc_paths "container" "develop"
  [ "$status" -eq 0 ]
  [ "$output" = $'minmax/doc\nstring/doc' ]

  restore_mock_gh
}

@test "get_doc_paths: API failure returns non-zero" {
  # shellcheck source=tests/helpers/mock_gh.bash
  source "$BATS_TEST_DIRNAME/helpers/mock_gh.bash"
  install_mock_gh
  export MOCK_GH_API_EXIT=1

  run get_doc_paths "algorithm" "develop"
  [ "$status" -eq 1 ]

  restore_mock_gh
}

@test "prune_to_doc_only: keeps doc and root files, removes other dirs" {
  # shellcheck source=tests/helpers/git_fixtures.bash
  source "$BATS_TEST_DIRNAME/helpers/git_fixtures.bash"
  init_git_fixture_root
  local_dir="$GIT_FIXTURE_ROOT/prune-single"
  create_prune_fixture_dir "$local_dir"
  echo "root" >"$local_dir/LICENSE"

  prune_to_doc_only "$local_dir" "doc"

  [ -d "$local_dir/doc" ]
  [ -f "$local_dir/LICENSE" ]
  [ ! -d "$local_dir/src" ]
  [ ! -d "$local_dir/.github" ]

  cleanup_git_fixture_root
}

@test "prune_to_doc_only: multi-level path prunes intermediate dirs" {
  # shellcheck source=tests/helpers/git_fixtures.bash
  source "$BATS_TEST_DIRNAME/helpers/git_fixtures.bash"
  init_git_fixture_root
  local_dir="$GIT_FIXTURE_ROOT/prune-multi"
  create_prune_fixture_dir "$local_dir"

  prune_to_doc_only "$local_dir" "minmax/doc"

  [ -d "$local_dir/minmax" ]
  [ ! -d "$local_dir/minmax/other" ]
  [ ! -d "$local_dir/doc" ]
  [ ! -d "$local_dir/src" ]

  cleanup_git_fixture_root
}

@test "require_lang_codes: succeeds when LANG_CODES is set" {
  export LANG_CODES="en,zh_Hans"
  run require_lang_codes
  [ "$status" -eq 0 ]
}

@test "require_lang_codes: fails when LANG_CODES is unset" {
  unset LANG_CODES
  run require_lang_codes
  [ "$status" -eq 1 ]
  [[ "$output" == *"lang_codes not set"* ]]
}

@test "require_lang_codes: fails when LANG_CODES is empty" {
  export LANG_CODES=""
  run require_lang_codes
  [ "$status" -eq 1 ]
  [[ "$output" == *"lang_codes not set"* ]]
}

@test "validate_secrets: succeeds when required workflow env is set" {
  load_env
  export GITHUB_TOKEN="test-token"
  export LANG_CODES="en"
  run validate_secrets
  [ "$status" -eq 0 ]
}

@test "validate_secrets: fails when GITHUB_TOKEN is unset" {
  load_env
  export LANG_CODES="en"
  unset GITHUB_TOKEN
  run validate_secrets
  [ "$status" -eq 1 ]
  [[ "$output" == *"SYNC_TOKEN secret is not set"* ]]
}

@test "validate_secrets: fails when LANG_CODES is unset" {
  load_env
  export GITHUB_TOKEN="test-token"
  unset LANG_CODES
  run validate_secrets
  [ "$status" -eq 1 ]
  [[ "$output" == *"lang_codes not set"* ]]
}

@test "validate_secrets weblate: succeeds when Weblate secrets are set" {
  load_env
  export GITHUB_TOKEN="test-token"
  export LANG_CODES="en"
  export WEBLATE_URL="https://weblate.example.org"
  export WEBLATE_TOKEN="weblate-token"
  run validate_secrets weblate
  [ "$status" -eq 0 ]
}

@test "validate_secrets weblate: fails when WEBLATE_URL is unset" {
  load_env
  export GITHUB_TOKEN="test-token"
  export LANG_CODES="en"
  export WEBLATE_TOKEN="weblate-token"
  unset WEBLATE_URL
  run validate_secrets weblate
  [ "$status" -eq 1 ]
  [[ "$output" == *"WEBLATE_URL secret is not set"* ]]
}
