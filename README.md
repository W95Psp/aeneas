<p><div style="text-align: center">
<img src="static/Aeneas.jpg"
     alt="Iapyx removing arrowhead from Aeneas" title="Iapyx removing arrowhead from Aeneas"
     style=""/>
<figcaption>
Unknown author, <i>Iapyx removing arrowhead from Aeneas</i> [Fresco].
Wall in Pompei, digital image from Michael Lahanis.
<a href="https://commons.wikimedia.org/w/index.php?curid=1357010">Source</a>
</figcaption>
</div></p>

# Aeneas [Ay-nay-as]

Aeneas (pronunced [Ay-nay-as]) is a verification toolchain for Rust programs.  It relies on a translation from Rusts's MIR
internal language to a pure lamdba calculus.  It is intended to be used in combination with
[Charon](https://github.com/AeneasVerif/charon), which compiles Rust programs to an intermediate
representation called LLBC. It currently has backends for [F\*](https://www.fstar-lang.org),
[Coq](https://coq.inria.fr/), [HOL4](https://hol-theorem-prover.org/) and [LEAN](https://leanprover.github.io/).

If you want to contribute or ask questions, we strongly encourage you to join the [Zulip](https://aeneas-verif.zulipchat.com/).

## Project Structure

- `src`: the OCaml sources. Note that we rely on [Dune](https://github.com/ocaml/dune)
  to build the project.
- `backends`: standard libraries for the existing backends (definitions for
   arithmetic operations, for standard collections like vectors, theorems, tactics, etc.)
- `tests`: files generated by applying Aeneas on some of the test files of Charon,
  completed with hand-written files (proof scripts, mostly).

## Installation & Build

You need to install OCaml, together with some packages.

We suggest you to follow those [instructions](https://ocaml.org/docs/install.html),
and install OPAM on the way (same instructions).

We use **OCaml 4.13.1**: `opam switch create 4.13.1+options`

The dependencies can then be installed with the following command:

```
opam install ppx_deriving visitors easy_logging zarith yojson core_unix odoc \
  unionFind ocamlgraph menhir ocamlformat
```

Moreover, Aeneas uses the [Charon](https://github.com/AeneasVerif/charon) project and library.
For Aeneas to work, `./charon` must contain a clone of the [Charon](https://github.com/AeneasVerif/charon)
repository, at the commit specified in `./charon-pin`.  The easiest way to set this up is to call
`make setup-charon`
(this uses either [rustup](https://rustup.rs/) or [nix](https://nixos.org/download/) to build Charon, depending on which one is installed).
In case of version mismatch, you will be instructed to update Charon.

If you're also developing on Charon, you can instead set up `./charon` to be a symlink to your local version:
`ln -s PATH_TO_CHARON_REPO charon`. In this case, the scripts will not check that your Charon
installation is on a compatible commit. When you pull a new version of Aeneas, you will occasionally
need to update your Charon repository so that Aeneas builds and runs correctly.

Finally, building the project simply requires running `make` in the top
directory.

You can also use `make test` and `make verify` to run the tests, and check
the generated files. As `make test` will run tests which use the Charon tests,
you will need to regenerate the `.llbc` files. To do this, run `make setup-charon` before `make
test`. Alternatively, call `REGEN_LLBC=1 make test-...` to regenerate only the needed files.

## Documentation

If you run `make`, you will generate a documentation accessible from [`doc.html`](./doc.html).

## Usage

The Aeneas binary is in `bin`; you can run: `./bin/aeneas -backend {fstar|coq|lean|hol4} [OPTIONS] LLBC_FILE`,
where `LLBC_FILE` is an .llbc file generated by Charon.

Aeneas provides a lot of flags and options to tweak its behaviour: you can use `--help`
to display a detailed documentation.

### Additional Steps for Lean Backend

Files generated by the Lean backend import the `Base` package from Aeneas.
To use those files in Lean, create a new Lean package using `lake new`,
overwrite the `lean-toolchain` with the one inside `./backends/lean`,
and add `base` as a dependency in the `lakefile.lean`:
```
require base from "PATH_TO_AENEAS_REPO/backends/lean"
```

## Targeted Subset And Current Limitations

We target **safe** Rust. This means we have no support for unsafe Rust, though we plan to
design a mechanism to allow using Aeneas in combination with tools targeting unsafe Rust.

We have the following limitations, that we plan to address one by one:

- **loops**: no nested loops for now. We are working on lifting this limitation.
- **no functions pointers/closures**: ongoing work. We have support for traits and
  will have support for function pointers and closures soon.
- **limited type parametricity**: it is not possible for now to instantiate a type
  parameter with a type containing a borrow. This is mostly an engineering
  issue.
- **no nested borrows in function signatures**: ongoing work.
- **interior mutability**: ongoing work. We are thinking of modeling the effects of
  interior mutability by using ghost states.
- **no concurrent execution**: long-term effort. We plan to address coarse-grained
  parallelism as a long-term goal.

## Backend Support

We currently support F\*, Coq, HOL4 and Lean. We would be interested in having an Isabelle
backend. Our most mature backends are Lean and HOL4, for which we have in particular
support for partial functions and extrinsic proofs of termination (see
`./backends/lean/Base/Diverge/Elab.lean` and `./backends/hol4/divDefLib.sig` for instance)
and tactics specialized for monadic programs (see
`./backends/lean/Base/Progress/Progress.lean` and `./backends/hol4/primitivesLib.sml`).

A tutorial for the Lean backend is available [here](./tests/lean/Tutorial.lean).

## Formalization

The translation has been formalized and published at ICFP2022: [Aeneas: Rust
verification by functional
translation](https://dl.acm.org/doi/abs/10.1145/3547647)
([long version](https://arxiv.org/abs/2206.07185)). We also have a proof that
the symbolic execution performed by Aeneas during its translation correctly
implements a borrow checker, and published it in a
[preprint](https://arxiv.org/abs/2404.02680).
