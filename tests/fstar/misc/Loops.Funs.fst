(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [loops]: function definitions *)
module Loops.Funs
open Primitives
include Loops.Types
include Loops.Clauses

#set-options "--z3rlimit 50 --fuel 1 --ifuel 1"

(** [loops::list_nth_mut_loop] *)
let rec list_nth_mut_loop_loop0_fwd
  (t : Type0) (ls : list_t t) (i : u32) :
  Tot (result t) (decreases (list_nth_mut_loop_decreases t ls i))
  =
  begin match ls with
  | ListCons x tl ->
    if i = 0
    then Return x
    else
      begin match u32_sub i 1 with
      | Fail e -> Fail e
      | Return i0 ->
        begin match list_nth_mut_loop_loop0_fwd t tl i0 with
        | Fail e -> Fail e
        | Return x0 -> Return x0
        end
      end
  | ListNil -> Fail Failure
  end

(** [loops::list_nth_mut_loop] *)
let list_nth_mut_loop_fwd (t : Type0) (ls : list_t t) (i : u32) : result t =
  begin match list_nth_mut_loop_loop0_fwd t ls i with
  | Fail e -> Fail e
  | Return x -> Return x
  end

(** [loops::list_nth_mut_loop] *)
let rec list_nth_mut_loop_loop0_back
  (t : Type0) (ls : list_t t) (i : u32) (ret : t) :
  Tot (result (list_t t)) (decreases (list_nth_mut_loop_decreases t ls i))
  =
  begin match ls with
  | ListCons x tl ->
    if i = 0
    then Return (ListCons ret tl)
    else
      begin match u32_sub i 1 with
      | Fail e -> Fail e
      | Return i0 ->
        begin match list_nth_mut_loop_loop0_back t tl i0 ret with
        | Fail e -> Fail e
        | Return l -> Return (ListCons x l)
        end
      end
  | ListNil -> Fail Failure
  end

(** [loops::list_nth_mut_loop] *)
let list_nth_mut_loop_back
  (t : Type0) (ls : list_t t) (i : u32) (ret : t) : result (list_t t) =
  begin match list_nth_mut_loop_loop0_back t ls i ret with
  | Fail e -> Fail e
  | Return l -> Return l
  end

