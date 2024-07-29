#!/usr/bin/env zsh

set -e
source ../../transcript_helpers.sh

# Reset DB to a known state
pg_reset_fixtures

login_user_for_ucm 'transcripts'
transcript_ucm transcript prelude.md

echo 'get-causal-hash'
causalHash="$(fetch_data "$transcript_user" GET 'get-causal-hash' '/users/transcripts/projects/search/branches/main/browse' 2>/dev/null | jq -r '.namespaceListingHash')"

echo 'create-release'
# Create a release so it will be indexed
fetch "$transcript_user" POST create-release '/users/transcripts/projects/search/releases' "{
    \"causalHash\": \"${causalHash}\",
    \"major\": 1,
    \"minor\": 2,
    \"patch\": 3
}"

echo 'check-indexed'
# We have to wait for it to be indexed
for i in {1..10}; do
    if fetch_data "$transcript_user" GET 'check-indexed' '/search-names?query=const' | jq -e '(. | length) > 0' 2>/dev/null >/dev/null; then
      echo 'Found definition search results, continuing...';
      break;
    # If we're on the last iteration fail the transcript
    elif [[ "$i" -ge 10 ]] then
      echo 'Failed to find any definition search results before timeout.';
      exit 1;
    fi
    sleep 3;
done

# Name searches
fetch "$transcript_user" GET 'name-search-suffix' '/search-names?query=const'
fetch "$transcript_user" GET 'name-search-prefix' '/search-names?query=Func'
fetch "$transcript_user" GET 'name-search-infix' '/search-names?query=List.ma'

# Type searches
# "b -> a -> a"
fetch "$transcript_user" GET 'type-var-search' '/search-definitions?query=b%20-%3E%20a%20-%3E%20a'

# (a -> b) -> List a -> List b
fetch "$transcript_user" GET 'complex-type-mention-search' '/search-definitions?query=(a%20-%3E%20b)%20-%3E%20List%20a%20-%3E%20List%20b'

# Similar type search, should find 'map' but not 'usesListLike'
# List a -> List b
fetch "$transcript_user" GET 'similar-type-search' '/search-definitions?query=List%20a%20-%3E%20List%20b'

# Return-type sorting. Should sort Nat.toText first
# Nat -> Text
fetch "$transcript_user" GET 'return-type-sorting-1' '/search-definitions?query=Nat%20-%3E%20Text'

# Return-type sorting. Should sort Nat.fromText first
# Text -> Nat
fetch "$transcript_user" GET 'return-type-sorting-2' '/search-definitions?query=Text%20-%3E%20Nat'
