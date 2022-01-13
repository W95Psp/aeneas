(* TODO: most of the definitions in this file need to be moved elsewhere *)

module T = Types
module V = Values
module E = Expressions
module C = Contexts
module Subst = Substitute
module A = CfimAst
module L = Logging
open Utils
open TypesUtils
module PA = Print.EvalCtxCfimAst

(** Some utilities *)

let eval_ctx_to_string = Print.Contexts.eval_ctx_to_string

let ety_to_string = PA.ety_to_string

let rty_to_string = PA.rty_to_string

let symbolic_value_to_string = PA.symbolic_value_to_string

let borrow_content_to_string = PA.borrow_content_to_string

let loan_content_to_string = PA.loan_content_to_string

let aborrow_content_to_string = PA.aborrow_content_to_string

let aloan_content_to_string = PA.aloan_content_to_string

let typed_value_to_string = PA.typed_value_to_string

let typed_avalue_to_string = PA.typed_avalue_to_string

let place_to_string = PA.place_to_string

let operand_to_string = PA.operand_to_string

let statement_to_string ctx = PA.statement_to_string ctx "" "  "

let statement_to_string_with_tab ctx = PA.statement_to_string ctx "  " "  "

let same_symbolic_id (sv0 : V.symbolic_value) (sv1 : V.symbolic_value) : bool =
  sv0.V.sv_id = sv1.V.sv_id

let mk_var (index : V.VarId.id) (name : string option) (var_ty : T.ety) : A.var
    =
  { A.index; name; var_ty }

(** Small helper - TODO: move *)
let mk_place_from_var_id (var_id : V.VarId.id) : E.place =
  { var_id; projection = [] }

(** Create a fresh symbolic value *)
let mk_fresh_symbolic_value (ty : T.rty) : V.symbolic_value =
  let sv_id = C.fresh_symbolic_value_id () in
  let svalue = { V.sv_id; V.sv_ty = ty } in
  svalue

(** Create a typed value from a symbolic value. *)
let mk_typed_value_from_symbolic_value (svalue : V.symbolic_value) :
    V.typed_value =
  let av = V.Symbolic svalue in
  let av : V.typed_value =
    { V.value = av; V.ty = Subst.erase_regions svalue.V.sv_ty }
  in
  av

(** Create a loans projector from a symbolic value. *)
let mk_aproj_loans_from_symbolic_value (svalue : V.symbolic_value) :
    V.typed_avalue =
  let av = V.ASymbolic (V.AProjLoans svalue) in
  let av : V.typed_avalue = { V.value = av; V.ty = svalue.V.sv_ty } in
  av

(** TODO: move *)
let borrow_is_asb (bid : V.BorrowId.id) (asb : V.abstract_shared_borrow) : bool
    =
  match asb with
  | V.AsbBorrow bid' -> bid' = bid
  | V.AsbProjReborrows _ -> false

(** TODO: move *)
let borrow_in_asb (bid : V.BorrowId.id) (asb : V.abstract_shared_borrows) : bool
    =
  List.exists (borrow_is_asb bid) asb

(** TODO: move *)
let remove_borrow_from_asb (bid : V.BorrowId.id)
    (asb : V.abstract_shared_borrows) : V.abstract_shared_borrows =
  let removed = ref 0 in
  let asb =
    List.filter
      (fun asb ->
        if not (borrow_is_asb bid asb) then true
        else (
          removed := !removed + 1;
          false))
      asb
  in
  assert (!removed = 1);
  asb

(** We sometimes need to return a value whose type may vary depending on
    whether we find it in a "concrete" value or an abstraction (ex.: loan
    contents when we perform environment lookups by using borrow ids) *)
type ('a, 'b) concrete_or_abs = Concrete of 'a | Abstract of 'b

type g_loan_content = (V.loan_content, V.aloan_content) concrete_or_abs
(** Generic loan content: concrete or abstract *)

type g_borrow_content = (V.borrow_content, V.aborrow_content) concrete_or_abs
(** Generic borrow content: concrete or abstract *)

type abs_or_var_id = AbsId of V.AbstractionId.id | VarId of V.VarId.id option

exception FoundBorrowContent of V.borrow_content
(** Utility exception *)

exception FoundLoanContent of V.loan_content
(** Utility exception *)

exception FoundABorrowContent of V.aborrow_content
(** Utility exception *)

exception FoundGBorrowContent of g_borrow_content
(** Utility exception *)

exception FoundGLoanContent of g_loan_content
(** Utility exception *)

let symbolic_value_id_in_ctx (sv_id : V.SymbolicValueId.id) (ctx : C.eval_ctx) :
    bool =
  let obj =
    object
      inherit [_] C.iter_eval_ctx

      method! visit_Symbolic _ sv =
        if sv.V.sv_id = sv_id then raise Found else ()

      method! visit_ASymbolic _ aproj =
        match aproj with
        | AProjLoans sv | AProjBorrows (sv, _) ->
            if sv.V.sv_id = sv_id then raise Found else ()

      method! visit_abstract_shared_borrows _ asb =
        let visit (asb : V.abstract_shared_borrow) : unit =
          match asb with
          | V.AsbBorrow _ -> ()
          | V.AsbProjReborrows (sv, _) ->
              if sv.V.sv_id = sv_id then raise Found else ()
        in
        List.iter visit asb
    end
  in
  (* We use exceptions *)
  try
    obj#visit_eval_ctx () ctx;
    false
  with Found -> true

(** Check that a symbolic value doesn't contain ended regions.

    Note that we don't check that the set of ended regions is empty: we
    check that the set of ended regions doesn't intersect the set of
    regions used in the type (this is more general).
*)
let symbolic_value_has_ended_regions (ended_regions : T.RegionId.set_t)
    (s : V.symbolic_value) : bool =
  let regions = rty_regions s.V.sv_ty in
  not (T.RegionId.Set.disjoint regions ended_regions)

(** Check if a [value] contains ⊥.

    Note that this function is very general: it also checks wether
    symbolic values contain already ended regions.
 *)
let bottom_in_value (ended_regions : T.RegionId.set_t) (v : V.typed_value) :
    bool =
  let obj =
    object
      inherit [_] V.iter_typed_value

      method! visit_Bottom _ = raise Found

      method! visit_symbolic_value _ s =
        if symbolic_value_has_ended_regions ended_regions s then raise Found
        else ()
    end
  in
  (* We use exceptions *)
  try
    obj#visit_typed_value () v;
    false
  with Found -> true

(** Check if an [avalue] contains ⊥.

    Note that this function is very general: it also checks wether
    symbolic values contain already ended regions.
    
    TODO: remove?
*)
let bottom_in_avalue (ended_regions : T.RegionId.set_t) (v : V.typed_avalue) :
    bool =
  let obj =
    object
      inherit [_] V.iter_typed_avalue

      method! visit_Bottom _ = raise Found

      method! visit_symbolic_value _ sv =
        if symbolic_value_has_ended_regions ended_regions sv then raise Found
        else ()

      method! visit_aproj _ ap =
        (* Nothing to do actually *)
        match ap with
        | V.AProjLoans _sv -> ()
        | V.AProjBorrows (_sv, _rty) -> ()
    end
  in
  (* We use exceptions *)
  try
    obj#visit_typed_avalue () v;
    false
  with Found -> true
