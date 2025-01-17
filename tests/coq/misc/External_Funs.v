(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [external]: function definitions *)
Require Import Primitives.
Import Primitives.
Require Import Coq.ZArith.ZArith.
Require Import List.
Import ListNotations.
Local Open Scope Primitives_scope.
Require Import External_Types.
Include External_Types.
Require Import External_FunsExternal.
Include External_FunsExternal.
Module External_Funs.

(** Trait implementation: [core::marker::{(core::marker::Copy for u32)#61}]
    Source: '/rustc/ad963232d9b987d66a6f8e6ec4141f672b8b9900/library/core/src/marker.rs', lines 47:29-47:65
    Name pattern: core::marker::Copy<u32> *)
Definition core_marker_CopyU32 : core_marker_Copy_t u32 := {|
  core_marker_Copy_tcore_marker_Copy_t_cloneCloneInst := core_clone_CloneU32;
|}.

(** [external::use_get]:
    Source: 'tests/src/external.rs', lines 9:0-9:37 *)
Definition use_get
  (rc : core_cell_Cell_t u32) (st : state) : result (state * u32) :=
  core_cell_Cell_get u32 core_marker_CopyU32 rc st
.

(** [external::incr]:
    Source: 'tests/src/external.rs', lines 13:0-13:31 *)
Definition incr
  (rc : core_cell_Cell_t u32) (st : state) :
  result (state * (core_cell_Cell_t u32))
  :=
  p <- core_cell_Cell_get_mut u32 rc st;
  let (st1, p1) := p in
  let (i, get_mut_back) := p1 in
  i1 <- u32_add i 1%u32;
  p2 <- get_mut_back i1 st1;
  let (_, rc1) := p2 in
  Ok (st1, rc1)
.

End External_Funs.
