// Deliberately dependency-free: `go build` then needs no network and no go.sum,
// which matters because a fresh machine builds this before much else exists.
//
// go 1.22 is the version Ubuntu 24.04 ships (apt golang-go = 1.22.2), so this
// stays buildable by whatever a bare machine has. Do not raise it without
// checking `/usr/lib/go-1.22/bin/go build ./...` still passes.
module dotconfig/bstool

go 1.22
