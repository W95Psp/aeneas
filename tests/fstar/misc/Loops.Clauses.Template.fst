(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [loops]: templates for the decreases clauses *)
module Loops.Clauses.Template
open Primitives
open Loops.Types

#set-options "--z3rlimit 50 --fuel 1 --ifuel 1"

(** [loops::sum]: decreases clause
    Source: 'tests/src/loops.rs', lines 8:0-18:1 *)
unfold let sum_loop_decreases (max : u32) (i : u32) (s : u32) : nat = admit ()

(** [loops::sum_with_mut_borrows]: decreases clause
    Source: 'tests/src/loops.rs', lines 23:0-35:1 *)
unfold
let sum_with_mut_borrows_loop_decreases (max : u32) (i : u32) (s : u32) : nat =
  admit ()

(** [loops::sum_with_shared_borrows]: decreases clause
    Source: 'tests/src/loops.rs', lines 38:0-52:1 *)
unfold
let sum_with_shared_borrows_loop_decreases (max : u32) (i : u32) (s : u32) :
  nat =
  admit ()

(** [loops::sum_array]: decreases clause
    Source: 'tests/src/loops.rs', lines 54:0-62:1 *)
unfold
let sum_array_loop_decreases (n : usize) (a : array u32 n) (i : usize)
  (s : u32) : nat =
  admit ()

(** [loops::clear]: decreases clause
    Source: 'tests/src/loops.rs', lines 66:0-72:1 *)
unfold
let clear_loop_decreases (v : alloc_vec_Vec u32) (i : usize) : nat = admit ()

(** [loops::list_mem]: decreases clause
    Source: 'tests/src/loops.rs', lines 80:0-89:1 *)
unfold let list_mem_loop_decreases (x : u32) (ls : list_t u32) : nat = admit ()

(** [loops::list_nth_mut_loop]: decreases clause
    Source: 'tests/src/loops.rs', lines 92:0-102:1 *)
unfold
let list_nth_mut_loop_loop_decreases (t : Type0) (ls : list_t t) (i : u32) :
  nat =
  admit ()

(** [loops::list_nth_shared_loop]: decreases clause
    Source: 'tests/src/loops.rs', lines 105:0-115:1 *)
unfold
let list_nth_shared_loop_loop_decreases (t : Type0) (ls : list_t t) (i : u32) :
  nat =
  admit ()

(** [loops::get_elem_mut]: decreases clause
    Source: 'tests/src/loops.rs', lines 117:0-131:1 *)
unfold
let get_elem_mut_loop_decreases (x : usize) (ls : list_t usize) : nat =
  admit ()

(** [loops::get_elem_shared]: decreases clause
    Source: 'tests/src/loops.rs', lines 133:0-147:1 *)
unfold
let get_elem_shared_loop_decreases (x : usize) (ls : list_t usize) : nat =
  admit ()

(** [loops::list_nth_mut_loop_with_id]: decreases clause
    Source: 'tests/src/loops.rs', lines 158:0-169:1 *)
unfold
let list_nth_mut_loop_with_id_loop_decreases (t : Type0) (i : u32)
  (ls : list_t t) : nat =
  admit ()

(** [loops::list_nth_shared_loop_with_id]: decreases clause
    Source: 'tests/src/loops.rs', lines 172:0-183:1 *)
unfold
let list_nth_shared_loop_with_id_loop_decreases (t : Type0) (i : u32)
  (ls : list_t t) : nat =
  admit ()

(** [loops::list_nth_mut_loop_pair]: decreases clause
    Source: 'tests/src/loops.rs', lines 188:0-209:1 *)
unfold
let list_nth_mut_loop_pair_loop_decreases (t : Type0) (ls0 : list_t t)
  (ls1 : list_t t) (i : u32) : nat =
  admit ()

(** [loops::list_nth_shared_loop_pair]: decreases clause
    Source: 'tests/src/loops.rs', lines 212:0-233:1 *)
unfold
let list_nth_shared_loop_pair_loop_decreases (t : Type0) (ls0 : list_t t)
  (ls1 : list_t t) (i : u32) : nat =
  admit ()

(** [loops::list_nth_mut_loop_pair_merge]: decreases clause
    Source: 'tests/src/loops.rs', lines 237:0-252:1 *)
unfold
let list_nth_mut_loop_pair_merge_loop_decreases (t : Type0) (ls0 : list_t t)
  (ls1 : list_t t) (i : u32) : nat =
  admit ()

(** [loops::list_nth_shared_loop_pair_merge]: decreases clause
    Source: 'tests/src/loops.rs', lines 255:0-270:1 *)
unfold
let list_nth_shared_loop_pair_merge_loop_decreases (t : Type0) (ls0 : list_t t)
  (ls1 : list_t t) (i : u32) : nat =
  admit ()

(** [loops::list_nth_mut_shared_loop_pair]: decreases clause
    Source: 'tests/src/loops.rs', lines 273:0-288:1 *)
unfold
let list_nth_mut_shared_loop_pair_loop_decreases (t : Type0) (ls0 : list_t t)
  (ls1 : list_t t) (i : u32) : nat =
  admit ()

(** [loops::list_nth_mut_shared_loop_pair_merge]: decreases clause
    Source: 'tests/src/loops.rs', lines 292:0-307:1 *)
unfold
let list_nth_mut_shared_loop_pair_merge_loop_decreases (t : Type0)
  (ls0 : list_t t) (ls1 : list_t t) (i : u32) : nat =
  admit ()

(** [loops::list_nth_shared_mut_loop_pair]: decreases clause
    Source: 'tests/src/loops.rs', lines 311:0-326:1 *)
unfold
let list_nth_shared_mut_loop_pair_loop_decreases (t : Type0) (ls0 : list_t t)
  (ls1 : list_t t) (i : u32) : nat =
  admit ()

(** [loops::list_nth_shared_mut_loop_pair_merge]: decreases clause
    Source: 'tests/src/loops.rs', lines 330:0-345:1 *)
unfold
let list_nth_shared_mut_loop_pair_merge_loop_decreases (t : Type0)
  (ls0 : list_t t) (ls1 : list_t t) (i : u32) : nat =
  admit ()

(** [loops::ignore_input_mut_borrow]: decreases clause
    Source: 'tests/src/loops.rs', lines 349:0-353:1 *)
unfold let ignore_input_mut_borrow_loop_decreases (i : u32) : nat = admit ()

(** [loops::incr_ignore_input_mut_borrow]: decreases clause
    Source: 'tests/src/loops.rs', lines 357:0-362:1 *)
unfold
let incr_ignore_input_mut_borrow_loop_decreases (i : u32) : nat = admit ()

(** [loops::ignore_input_shared_borrow]: decreases clause
    Source: 'tests/src/loops.rs', lines 366:0-370:1 *)
unfold let ignore_input_shared_borrow_loop_decreases (i : u32) : nat = admit ()

