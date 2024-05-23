ifeq (3.81,$(MAKE_VERSION))
  $(error You seem to be using the OSX antiquated Make version. Hint: brew \
    install make, then invoke gmake instead of make)
endif

.PHONY: default
default: build

.PHONY: all
all: build-tests-verify nix

####################################
# Variables customizable by the user
####################################

# Paths to the executables we need for tests. They are overriden in CI.
AENEAS_EXE ?= $(PWD)/bin/aeneas
TEST_RUNNER_EXE ?= $(PWD)/bin/test_runner
CHARON_EXE ?= $(PWD)/charon/bin/charon

# The user can specify additional translation options for Aeneas.
# In CI we activate the (expensive) sanity checks.
OPTIONS ?=
CHARON_OPTIONS ?=

# The directory thta contains the rust source files for tests.
INPUTS_DIR ?= tests/src
# The directory where to look for the .llbc files.
LLBC_DIR ?= $(PWD)/tests/llbc

# In CI, we enforce formatting and we don't regenerate llbc files.
IN_CI ?=

####################################
# The rules
####################################

# Never remove intermediate files
.SECONDARY:

# Build the compiler, after formatting the code
.PHONY: build
build: format build-dev

# Build the project, test it and verify the generated files
.PHONY: build-test-verify
build-test-verify: build test verify

# Build the project, without formatting the code
.PHONY: build-dev
build-dev: build-bin build-lib build-bin-dir doc

.PHONY: build-bin
build-bin: check-charon
	cd compiler && dune build

.PHONY: build-lib
build-lib: check-charon
	cd compiler && dune build aeneas.cmxs

.PHONY: build-runner
build-runner: check-charon
	cd tests/test_runner && dune build

.PHONY: build-bin-dir
build-bin-dir: build-bin build-lib build-runner
	mkdir -p bin
	cp -f compiler/_build/default/main.exe bin/aeneas
	cp -f compiler/_build/default/main.exe bin/aeneas.cmxs
	cp -f tests/test_runner/_build/default/run_test.exe bin/test_runner
	mkdir -p bin/backends/fstar
	mkdir -p bin/backends/coq
	cp -rf backends/fstar/*.fst* bin/backends/fstar/
	cp -rf backends/coq/*.v bin/backends/coq/

.PHONY: doc
doc:
	cd compiler && dune build @doc

# Fetches the latest commit from charon and updates `flake.lock` accordingly.
.PHONY: update-charon-pin
update-charon-pin:
	nix flake lock --update-input charon
	$(MAKE) charon-pin

# Keep the commit revision in `./charon-pin` as well so that non-nix users can
# know which commit to use.
./charon-pin: flake.lock
	nix-shell -p jq --run './scripts/update-charon-pin.sh' >> ./charon-pin

# Checks that `./charon` contains a clone of charon at the required commit.
# Also checks that `./charon/bin/charon` exists.
.PHONY: check-charon
check-charon:
	@echo "Checking the charon installation"
	@./scripts/check-charon-install.sh

# Sets up the charon repository on the right commit.
.PHONY: setup-charon
setup-charon:
	@./scripts/check-charon-install.sh --force

ifdef IN_CI
# In CI, error if formatting is not done.
format: RUSTFMT_FLAGS := --check
endif

# Reformat the project files
.PHONY: format
format:
	@# `|| `true` because the command returns an error if it changed anything, which we don't care about.
	cd compiler && dune fmt || true
	cd tests/test_runner && dune fmt || true
	rustfmt $(RUSTFMT_FLAGS) $(INPUTS_DIR)/*.rs
	cd $(INPUTS_DIR)/betree && cargo fmt $(RUSTFMT_FLAGS)

.PHONY: clean
clean: clean-generated
	cd compiler && dune clean
	cd $(INPUTS_DIR)/betree && $(MAKE) clean

.PHONY: clean-generated
clean-generated: clean-generated-aeneas clean-generated-llbc

.PHONY: clean-generated-aeneas
clean-generated-aeneas:
	@# We can't put this line in `tests/Makefile` otherwise it will detect itself.
	@# FIXME: generation of hol4 files is deactivated so we don't delete those.
	@# `|| true` to avoid failing if there are no generated files present.
	grep -lR 'THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS' tests | grep -v '^tests/hol4' | xargs rm || true

.PHONY: clean-generated-llbc
clean-generated-llbc:
	rm -rf $(LLBC_DIR)

# =============================================================================
# The tests.
# =============================================================================

# Test the project by translating test files to various backends.
.PHONY: test
test: build-dev test-all betree-tests

# This runs the rust tests of the betree crate.
.PHONY: betree-tests
betree-tests:
	cd $(INPUTS_DIR)/betree && $(MAKE) test

.PHONY: test-all
test-all: \
	test-arrays \
	test-betree_main \
	test-bitwise \
	test-constants \
	test-demo \
	test-external \
	test-hashmap \
	test-hashmap_main \
	test-loops \
	test-no_nested_borrows \
	test-paper \
	test-polonius_list \
	test-traits

# Verify the F* files generated by the translation
.PHONY: verify
verify:
	cd tests && $(MAKE) all

ifdef IN_CI
# In CI we do extra sanity checks.
test-%: OPTIONS += -checks
endif

# Translate the given llbc file to available backends. The test runner decides
# which backends to use and sets test-specific options.
.PHONY: test-%
test-%: TEST_NAME = $*
test-%: $(LLBC_DIR)/%.llbc
	$(TEST_RUNNER_EXE) $(AENEAS_EXE) $(LLBC_DIR) $(TEST_NAME) $(OPTIONS)
	echo "# Test $* done"

#  List the `.rs` files in `$(INPUTS_DIR)/`
INDIVIDUAL_RUST_SRCS = $(wildcard $(INPUTS_DIR)/*.rs)
# We test all rust files except this one.
INDIVIDUAL_RUST_SRCS := $(filter-out $(INPUTS_DIR)/hashmap_utils.rs, $(INDIVIDUAL_RUST_SRCS))
# List the corresponding llbc files.
INDIVIDUAL_LLBCS := $(subst $(INPUTS_DIR)/,$(LLBC_DIR)/,$(patsubst %.rs,%.llbc,$(INDIVIDUAL_RUST_SRCS)))

.PHONY: generate-llbc
# This depends on `llbc/<file>.llbc` for each `$(INPUTS_DIR)/<file>.rs` we care about, plus the whole-crate test.
generate-llbc: $(INDIVIDUAL_LLBCS) $(LLBC_DIR)/betree_main.llbc

$(LLBC_DIR)/hashmap_main.llbc: CHARON_OPTIONS += --opaque=hashmap_utils
$(LLBC_DIR)/nested_borrows.llbc: CHARON_OPTIONS += --no-code-duplication
$(LLBC_DIR)/no_nested_borrows.llbc: CHARON_OPTIONS += --no-code-duplication
$(LLBC_DIR)/paper.llbc: CHARON_OPTIONS += --no-code-duplication
$(LLBC_DIR)/constants.llbc: CHARON_OPTIONS += --no-code-duplication
$(LLBC_DIR)/external.llbc: CHARON_OPTIONS += --no-code-duplication
$(LLBC_DIR)/polonius_list.llbc: CHARON_OPTIONS += --polonius
# Possible to add `--no-code-duplication` if we use the optimized MIR
$(LLBC_DIR)/betree_main.llbc: CHARON_OPTIONS += --polonius --opaque=betree_utils --crate betree_main

ifndef IN_CI
$(LLBC_DIR)/%.llbc: check-charon

$(LLBC_DIR)/%.llbc:
	$(CHARON_EXE) --no-cargo --input $(INPUTS_DIR)/$*.rs --crate $* $(CHARON_OPTIONS) --dest $(LLBC_DIR)
# Special rule for the whole-crate test.
$(LLBC_DIR)/betree_main.llbc:
	cd $(INPUTS_DIR)/betree && $(CHARON_EXE) $(CHARON_OPTIONS) --dest $(LLBC_DIR)
else
$(LLBC_DIR)/%.llbc:
	@echo 'ERROR: llbc files should be built separately in CI'
	@false
endif


# =============================================================================
# Nix
# =============================================================================
# TODO: add the lean tests
.PHONY: nix
nix:
	nix build && nix flake check

.PHONY: nix-aeneas-tests
nix-aeneas-tests:
	nix build .#checks.x86_64-linux.aeneas-tests --show-trace -L

.PHONY: nix-aeneas-verify-fstar
nix-aeneas-verify-fstar:
	nix build .#checks.x86_64-linux.aeneas-verify-fstar --show-trace -L

.PHONY: nix-aeneas-verify-fstar-split
nix-aeneas-verify-fstar-split:
	nix build .#checks.x86_64-linux.aeneas-verify-fstar-split --show-trace -L

.PHONY: nix-aeneas-verify-coq
nix-aeneas-verify-coq:
	nix build .#checks.x86_64-linux.aeneas-verify-coq --show-trace -L

.PHONY: nix-aeneas-verify-lean
nix-aeneas-verify-lean:
	nix build .#checks.x86_64-linux.aeneas-verify-lean --show-trace -L

.PHONY: nix-aeneas-verify-hol4
nix-aeneas-verify-hol4:
	nix build .#checks.x86_64-linux.aeneas-verify-hol4 --show-trace -L
