(* The following module defines functions to check that some invariants
 * are always maintained by evaluation contexts *)

module T = Types
module V = Values
open Scalars
module E = Expressions
open Errors
module C = Contexts
module Subst = Substitute
module A = CfimAst
module L = Logging
open TypesUtils
open ValuesUtils
open InterpreterUtils

let debug_invariants : bool ref = ref false

type borrow_info = {
  loan_kind : T.ref_kind;
  loan_ids : V.BorrowId.set_t;
  borrow_ids : V.BorrowId.set_t;
}
[@@deriving show]

let borrows_infos_to_string (infos : borrow_info V.BorrowId.Map.t) : string =
  let bindings = V.BorrowId.Map.bindings infos in
  let bindings = List.map (fun (_, info) -> show_borrow_info info) bindings in
  String.concat "\n" bindings

type borrow_kind = Mut | Shared | Inactivated

(** Check that:
    - loans and borrows are correctly related
 *)
let check_loans_borrows_relation_invariant (ctx : C.eval_ctx) : unit =
  (* Link all the borrow ids to a representant - necessary because of shared
   * borrows/loans *)
  let ids_reprs : V.BorrowId.id V.BorrowId.Map.t ref =
    ref V.BorrowId.Map.empty
  in
  (* Link all the id representants to a borrow information *)
  let borrows_infos : borrow_info V.BorrowId.Map.t ref =
    ref V.BorrowId.Map.empty
  in

  (* First, register all the loans *)
  (* Some utilities to register the loans *)
  let register_shared_loan (bids : V.BorrowId.set_t) : unit =
    let reprs = !ids_reprs in
    let infos = !borrows_infos in
    (* Use the first borrow id as representant *)
    let repr_bid = V.BorrowId.Set.min_elt bids in
    assert (not (V.BorrowId.Map.mem repr_bid infos));
    (* Insert the mappings to the representant *)
    let reprs =
      V.BorrowId.Set.fold
        (fun bid reprs ->
          assert (not (V.BorrowId.Map.mem bid reprs));
          V.BorrowId.Map.add bid repr_bid reprs)
        bids reprs
    in
    (* Insert the loan info *)
    let info =
      {
        loan_kind = T.Shared;
        loan_ids = bids;
        borrow_ids = V.BorrowId.Set.empty;
      }
    in
    let infos = V.BorrowId.Map.add repr_bid info infos in
    (* Update *)
    ids_reprs := reprs;
    borrows_infos := infos
  in

  let register_mut_loan (bid : V.BorrowId.id) : unit =
    let reprs = !ids_reprs in
    let infos = !borrows_infos in
    (* Sanity checks *)
    assert (not (V.BorrowId.Map.mem bid reprs));
    assert (not (V.BorrowId.Map.mem bid infos));
    (* Add the mapping for the representant *)
    let reprs = V.BorrowId.Map.add bid bid reprs in
    (* Add the mapping for the loan info *)
    let info =
      {
        loan_kind = T.Mut;
        loan_ids = V.BorrowId.Set.singleton bid;
        borrow_ids = V.BorrowId.Set.empty;
      }
    in
    let infos = V.BorrowId.Map.add bid info infos in
    (* Update *)
    ids_reprs := reprs;
    borrows_infos := infos
  in

  let loans_visitor =
    object
      inherit [_] C.iter_eval_ctx as super

      method! visit_loan_content env lc =
        (* Register the loan *)
        let _ =
          match lc with
          | V.SharedLoan (bids, tv) -> register_shared_loan bids
          | V.MutLoan bid -> register_mut_loan bid
        in
        (* Continue exploring *)
        super#visit_loan_content env lc

      method! visit_aloan_content env lc =
        let _ =
          match lc with
          | V.AMutLoan (bid, _) -> register_mut_loan bid
          | V.ASharedLoan (bids, _, _) -> register_shared_loan bids
          | V.AEndedMutLoan { given_back = _; child = _ }
          | V.AEndedSharedLoan (_, _)
          | V.AIgnoredMutLoan (_, _) (* We might want to do something here *)
          | V.AEndedIgnoredMutLoan { given_back = _; child = _ }
          | V.AIgnoredSharedLoan _ ->
              (* Do nothing *)
              ()
        in
        (* Continue exploring *)
        super#visit_aloan_content env lc
    end
  in

  (* Visit *)
  loans_visitor#visit_eval_ctx () ctx;

  (* Then, register all the borrows *)
  (* Some utilities to register the borrows *)
  let find_info (bid : V.BorrowId.id) : borrow_info =
    (* Find the representant *)
    let repr_bid = V.BorrowId.Map.find bid !ids_reprs in
    (* Lookup the info *)
    V.BorrowId.Map.find repr_bid !borrows_infos
  in
  let update_info (bid : V.BorrowId.id) (info : borrow_info) : unit =
    (* Find the representant *)
    let repr_bid = V.BorrowId.Map.find bid !ids_reprs in
    (* Update the info *)
    let infos =
      V.BorrowId.Map.update repr_bid
        (fun x ->
          match x with Some _ -> Some info | None -> failwith "Unreachable")
        !borrows_infos
    in
    borrows_infos := infos
  in

  let register_borrow (kind : borrow_kind) (bid : V.BorrowId.id) : unit =
    (* Lookup the info *)
    let info = find_info bid in
    (* Check that the borrow kind is consistent *)
    (match (info.loan_kind, kind) with
    | T.Shared, (Shared | Inactivated) | T.Mut, Mut -> ()
    | _ -> failwith "Invariant not satisfied");
    (* Insert the borrow id *)
    let borrow_ids = info.borrow_ids in
    assert (not (V.BorrowId.Set.mem bid borrow_ids));
    let info = { info with borrow_ids = V.BorrowId.Set.add bid borrow_ids } in
    (* Update the info in the map *)
    update_info bid info
  in

  let borrows_visitor =
    object
      inherit [_] C.iter_eval_ctx as super

      method! visit_abstract_shared_borrows _ asb =
        let visit asb =
          match asb with
          | V.AsbBorrow bid -> register_borrow Shared bid
          | V.AsbProjReborrows _ -> ()
        in
        List.iter visit asb

      method! visit_borrow_content env bc =
        (* Register the loan *)
        let _ =
          match bc with
          | V.SharedBorrow bid -> register_borrow Shared bid
          | V.MutBorrow (bid, _) -> register_borrow Mut bid
          | V.InactivatedMutBorrow bid -> register_borrow Inactivated bid
        in
        (* Continue exploring *)
        super#visit_borrow_content env bc

      method! visit_aborrow_content env bc =
        let _ =
          match bc with
          | V.AMutBorrow (bid, _) -> register_borrow Mut bid
          | V.ASharedBorrow bid -> register_borrow Shared bid
          | V.AIgnoredMutBorrow _ | V.AProjSharedBorrow _ ->
              (* Do nothing *)
              ()
        in
        (* Continue exploring *)
        super#visit_aborrow_content env bc
    end
  in

  (* Visit *)
  borrows_visitor#visit_eval_ctx () ctx;

  (* Debugging *)
  if !debug_invariants then (
    L.log#ldebug
      (lazy
        ("\nAbout to check context invariant:\n" ^ eval_ctx_to_string ctx ^ "\n"));
    L.log#ldebug
      (lazy
        ("\Borrows information:\n"
        ^ borrows_infos_to_string !borrows_infos
        ^ "\n")));

  (* Finally, check that everything is consistant *)
  V.BorrowId.Map.iter
    (fun _ info ->
      (* Note that we can't directly compare the sets - I guess they are
       * different depending on the order in which we add the elements... *)
      assert (
        V.BorrowId.Set.elements info.loan_ids
        = V.BorrowId.Set.elements info.borrow_ids);
      match info.loan_kind with
      | T.Mut -> assert (V.BorrowId.Set.cardinal info.loan_ids = 1)
      | T.Shared -> ())
    !borrows_infos

(** Check that:
    - borrows/loans can't contain ⊥ or inactivated mut borrows
    - shared loans can't contain mutable loans
    - TODO: a two-phase borrow can't point to a value inside an abstraction
 *)
let check_borrowed_values_invariant (ctx : C.eval_ctx) : unit = ()

let check_typing_invariant (ctx : C.eval_ctx) : unit = ()

let check_invariants (ctx : C.eval_ctx) : unit =
  check_loans_borrows_relation_invariant ctx;
  check_borrowed_values_invariant ctx;
  check_typing_invariant ctx
