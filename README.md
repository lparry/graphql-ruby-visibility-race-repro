# GraphQL-Ruby visibility reference-index race

This small reproduction demonstrates that a concurrent caller can observe an
incomplete `GraphQL::Schema::Visibility` reference index while it is first being
built. The `Icon` type is reachable through `Avatar`, but its reference is not
visible until the first traversal completes.

The script pauses the real schema traversal after it starts, reads the index
from a second thread, then resumes the traversal. It uses a static schema so
the result does not depend on application autoloading or dynamic type
generation.

## Run

Requires Ruby and Bundler. The reproduction pins graphql-ruby 2.6.11, the
version used for the reported reproduction.

```sh
bundle install
bundle exec ruby repro.rb
```

Expected output:

```text
Starting visibility reference-index traversal.
The test pauses that traversal, then reads the index from another thread.
While traversal is paused, Icon reference count is 0 (expected 0: index is incomplete).
After traversal completes, Icon reference count is 1 (expected 1: Avatar references Icon).
RACE REPRODUCED: the concurrent read returned before the reference index was ready.
```

The script exits unsuccessfully with `RACE NOT REPRODUCED` if the observed
counts differ. That may mean the race has been fixed or traversal behavior has
changed in the tested version.

## Scope

This proves that an in-flight concurrent read can see a partial reference
index, then see the completed index after traversal. It does not reproduce the
application's separate observation that failures appeared to persist on one
Puma request-serving thread until reboot, and does not establish what state
caused that persistence.
