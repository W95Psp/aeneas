(* The following module defines functions to check that some invariants
 * are always maintained by evaluation contexts *)

open Types
open Values
open Contexts
open TypesUtils
open InterpreterUtils
open InterpreterBorrowsCore
open Errors

(** The local logger *)
let log = Logging.invariants_log

type borrow_info = {
  loan_kind : ref_kind;
  loan_in_abs : bool;
  (* true if the loan was found in an abstraction *)
  loan_ids : BorrowId.Set.t;
  borrow_ids : BorrowId.Set.t;
}
[@@deriving show]

type outer_borrow_info = {
  outer_borrow : bool;
  (* true if the value is borrowed *)
  outer_shared : bool; (* true if the value is borrowed as shared *)
}

let set_outer_mut (info : outer_borrow_info) : outer_borrow_info =
  { info with outer_borrow = true }

let set_outer_shared (_info : outer_borrow_info) : outer_borrow_info =
  { outer_borrow = true; outer_shared = true }

let ids_reprs_to_string (indent : string) (reprs : BorrowId.id BorrowId.Map.t) :
    string =
  BorrowId.Map.to_string (Some indent) BorrowId.to_string reprs

let borrows_infos_to_string (indent : string)
    (infos : borrow_info BorrowId.Map.t) : string =
  BorrowId.Map.to_string (Some indent) show_borrow_info infos

type borrow_kind = BMut | BShared | BReserved

(** Check that:
    - loans and borrows are correctly related
    - a two-phase borrow can't point to a value inside an abstraction
 *)
let check_loans_borrows_relation_invariant (span : Meta.span) (ctx : eval_ctx) :
    unit =
  (* Link all the borrow ids to a representant - necessary because of shared
   * borrows/loans *)
  let ids_reprs : BorrowId.id BorrowId.Map.t ref = ref BorrowId.Map.empty in
  (* Link all the id representants to a borrow information *)
  let borrows_infos : borrow_info BorrowId.Map.t ref = ref BorrowId.Map.empty in
  let context_to_string () : string =
    eval_ctx_to_string ~span:(Some span) ctx
    ^ "- representants:\n"
    ^ ids_reprs_to_string "  " !ids_reprs
    ^ "\n- info:\n"
    ^ borrows_infos_to_string "  " !borrows_infos
  in
  (* Ignored loans - when we find an ignored loan while building the borrows_infos
   * map, we register it in this list; once the borrows_infos map is completely
   * built, we check that all the borrow ids of the ignored loans are in this
   * map *)
  let ignored_loans : (ref_kind * BorrowId.id) list ref = ref [] in

  (* first, register all the loans *)
  (* Some utilities to register the loans *)
  let register_ignored_loan (rkind : ref_kind) (bid : BorrowId.id) : unit =
    ignored_loans := (rkind, bid) :: !ignored_loans
  in

  let register_shared_loan (loan_in_abs : bool) (bids : BorrowId.Set.t) : unit =
    let reprs = !ids_reprs in
    let infos = !borrows_infos in
    (* Use the first borrow id as representant *)
    let repr_bid = BorrowId.Set.min_elt bids in
    sanity_check __FILE__ __LINE__ (not (BorrowId.Map.mem repr_bid infos)) span;
    (* Insert the mappings to the representant *)
    let reprs =
      BorrowId.Set.fold
        (fun bid reprs ->
          sanity_check __FILE__ __LINE__ (not (BorrowId.Map.mem bid reprs)) span;
          BorrowId.Map.add bid repr_bid reprs)
        bids reprs
    in
    (* Insert the loan info *)
    let info =
      {
        loan_kind = RShared;
        loan_in_abs;
        loan_ids = bids;
        borrow_ids = BorrowId.Set.empty;
      }
    in
    let infos = BorrowId.Map.add repr_bid info infos in
    (* Update *)
    ids_reprs := reprs;
    borrows_infos := infos
  in

  let register_mut_loan (loan_in_abs : bool) (bid : BorrowId.id) : unit =
    let reprs = !ids_reprs in
    let infos = !borrows_infos in
    (* Sanity checks *)
    sanity_check __FILE__ __LINE__ (not (BorrowId.Map.mem bid reprs)) span;
    sanity_check __FILE__ __LINE__ (not (BorrowId.Map.mem bid infos)) span;
    (* Add the mapping for the representant *)
    let reprs = BorrowId.Map.add bid bid reprs in
    (* Add the mapping for the loan info *)
    let info =
      {
        loan_kind = RMut;
        loan_in_abs;
        loan_ids = BorrowId.Set.singleton bid;
        borrow_ids = BorrowId.Set.empty;
      }
    in
    let infos = BorrowId.Map.add bid info infos in
    (* Update *)
    ids_reprs := reprs;
    borrows_infos := infos
  in

  let loans_visitor =
    object
      inherit [_] iter_eval_ctx as super

      method! visit_EBinding _ binder v =
        let inside_abs = false in
        super#visit_EBinding inside_abs binder v

      method! visit_EAbs _ abs =
        let inside_abs = true in
        super#visit_EAbs inside_abs abs

      method! visit_loan_content inside_abs lc =
        (* Register the loan *)
        let _ =
          match lc with
          | VSharedLoan (bids, _) -> register_shared_loan inside_abs bids
          | VMutLoan bid -> register_mut_loan inside_abs bid
        in
        (* Continue exploring *)
        super#visit_loan_content inside_abs lc

      method! visit_aloan_content inside_abs lc =
        let _ =
          match lc with
          | AMutLoan (bid, _) -> register_mut_loan inside_abs bid
          | ASharedLoan (bids, _, _) -> register_shared_loan inside_abs bids
          | AIgnoredMutLoan (Some bid, _) -> register_ignored_loan RMut bid
          | AIgnoredMutLoan (None, _)
          | AIgnoredSharedLoan _
          | AEndedMutLoan { given_back = _; child = _; given_back_span = _ }
          | AEndedSharedLoan (_, _)
          | AEndedIgnoredMutLoan
              { given_back = _; child = _; given_back_span = _ } ->
              (* Do nothing *)
              ()
        in
        (* Continue exploring *)
        super#visit_aloan_content inside_abs lc
    end
  in

  (* Visit *)
  let inside_abs = false in
  loans_visitor#visit_eval_ctx inside_abs ctx;

  (* Then, register all the borrows *)
  (* Some utilities to register the borrows *)
  let find_info (bid : BorrowId.id) : borrow_info =
    (* Find the representant *)
    match BorrowId.Map.find_opt bid !ids_reprs with
    | Some repr_bid ->
        (* Lookup the info *)
        BorrowId.Map.find repr_bid !borrows_infos
    | None ->
        let err =
          "find_info: could not find the representant of borrow "
          ^ BorrowId.to_string bid ^ ":\nContext:\n" ^ context_to_string ()
        in
        craise __FILE__ __LINE__ span err
  in

  let update_info (bid : BorrowId.id) (info : borrow_info) : unit =
    (* Find the representant *)
    let repr_bid = BorrowId.Map.find bid !ids_reprs in
    (* Update the info *)
    let infos =
      BorrowId.Map.update repr_bid
        (fun x ->
          match x with
          | Some _ -> Some info
          | None -> craise __FILE__ __LINE__ span "Unreachable")
        !borrows_infos
    in
    borrows_infos := infos
  in

  let register_ignored_borrow = register_ignored_loan in

  let register_borrow (kind : borrow_kind) (bid : BorrowId.id) : unit =
    (* Lookup the info *)
    let info = find_info bid in
    (* Check that the borrow kind is consistent *)
    (match (info.loan_kind, kind) with
    | RShared, (BShared | BReserved) | RMut, BMut -> ()
    | _ -> craise __FILE__ __LINE__ span "Invariant not satisfied");
    (* A reserved borrow can't point to a value inside an abstraction *)
    sanity_check __FILE__ __LINE__
      (kind <> BReserved || not info.loan_in_abs)
      span;
    (* Insert the borrow id *)
    let borrow_ids = info.borrow_ids in
    sanity_check __FILE__ __LINE__ (not (BorrowId.Set.mem bid borrow_ids)) span;
    let info = { info with borrow_ids = BorrowId.Set.add bid borrow_ids } in
    (* Update the info in the map *)
    update_info bid info
  in

  let borrows_visitor =
    object
      inherit [_] iter_eval_ctx as super

      method! visit_abstract_shared_borrow _ asb =
        match asb with
        | AsbBorrow bid -> register_borrow BShared bid
        | AsbProjReborrows _ -> ()

      method! visit_borrow_content env bc =
        (* Register the loan *)
        let _ =
          match bc with
          | VSharedBorrow bid -> register_borrow BShared bid
          | VMutBorrow (bid, _) -> register_borrow BMut bid
          | VReservedMutBorrow bid -> register_borrow BReserved bid
        in
        (* Continue exploring *)
        super#visit_borrow_content env bc

      method! visit_aborrow_content env bc =
        let _ =
          match bc with
          | AMutBorrow (bid, _) -> register_borrow BMut bid
          | ASharedBorrow bid -> register_borrow BShared bid
          | AIgnoredMutBorrow (Some bid, _) -> register_ignored_borrow RMut bid
          | AIgnoredMutBorrow (None, _)
          | AEndedMutBorrow _ | AEndedIgnoredMutBorrow _ | AEndedSharedBorrow
          | AProjSharedBorrow _ ->
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
  log#ldebug
    (lazy ("\nAbout to check context invariant:\n" ^ context_to_string ()));

  (* Finally, check that everything is consistant *)
  (* First, check all the ignored loans are present at the proper place *)
  List.iter
    (fun (rkind, bid) ->
      let info = find_info bid in
      sanity_check __FILE__ __LINE__ (info.loan_kind = rkind) span)
    !ignored_loans;

  (* Then, check the borrow infos *)
  BorrowId.Map.iter
    (fun _ info ->
      (* Note that we can't directly compare the sets - I guess they are
       * different depending on the order in which we add the elements... *)
      sanity_check __FILE__ __LINE__
        (BorrowId.Set.elements info.loan_ids
        = BorrowId.Set.elements info.borrow_ids)
        span;
      match info.loan_kind with
      | RMut ->
          sanity_check __FILE__ __LINE__
            (BorrowId.Set.cardinal info.loan_ids = 1)
            span
      | RShared -> ())
    !borrows_infos

(** Check that:
    - borrows/loans can't contain ⊥ or reserved mut borrows
    - shared loans can't contain mutable loans
 *)
let check_borrowed_values_invariant (span : Meta.span) (ctx : eval_ctx) : unit =
  let visitor =
    object
      inherit [_] iter_eval_ctx as super

      method! visit_VBottom info =
        (* No ⊥ inside borrowed values *)
        sanity_check __FILE__ __LINE__
          (Config.allow_bottom_below_borrow || not info.outer_borrow)
          span

      method! visit_ABottom _info =
        (* ⊥ inside an abstraction is not the same as in a regular value *)
        ()

      method! visit_loan_content info lc =
        (* Update the info *)
        let info =
          match lc with
          | VSharedLoan (_, _) -> set_outer_shared info
          | VMutLoan _ ->
              (* No mutable loan inside a shared loan *)
              sanity_check __FILE__ __LINE__ (not info.outer_shared) span;
              set_outer_mut info
        in
        (* Continue exploring *)
        super#visit_loan_content info lc

      method! visit_borrow_content info bc =
        (* Update the info *)
        let info =
          match bc with
          | VSharedBorrow _ -> set_outer_shared info
          | VReservedMutBorrow _ ->
              sanity_check __FILE__ __LINE__ (not info.outer_borrow) span;
              set_outer_shared info
          | VMutBorrow (_, _) -> set_outer_mut info
        in
        (* Continue exploring *)
        super#visit_borrow_content info bc

      method! visit_aloan_content info lc =
        (* Update the info *)
        let info =
          match lc with
          | AMutLoan (_, _) -> set_outer_mut info
          | ASharedLoan (_, _, _) -> set_outer_shared info
          | AEndedMutLoan { given_back = _; child = _; given_back_span = _ } ->
              set_outer_mut info
          | AEndedSharedLoan (_, _) -> set_outer_shared info
          | AIgnoredMutLoan (_, _) -> set_outer_mut info
          | AEndedIgnoredMutLoan
              { given_back = _; child = _; given_back_span = _ } ->
              set_outer_mut info
          | AIgnoredSharedLoan _ -> set_outer_shared info
        in
        (* Continue exploring *)
        super#visit_aloan_content info lc

      method! visit_aborrow_content info bc =
        (* Update the info *)
        let info =
          match bc with
          | AMutBorrow (_, _) -> set_outer_mut info
          | ASharedBorrow _ | AEndedSharedBorrow -> set_outer_shared info
          | AIgnoredMutBorrow _ | AEndedMutBorrow _ | AEndedIgnoredMutBorrow _
            ->
              set_outer_mut info
          | AProjSharedBorrow _ -> set_outer_shared info
        in
        (* Continue exploring *)
        super#visit_aborrow_content info bc
    end
  in

  (* Explore *)
  let info = { outer_borrow = false; outer_shared = false } in
  visitor#visit_eval_ctx info ctx

let check_literal_type (span : Meta.span) (cv : literal) (ty : literal_type) :
    unit =
  match (cv, ty) with
  | VScalar sv, TInteger int_ty ->
      sanity_check __FILE__ __LINE__ (sv.int_ty = int_ty) span
  | VBool _, TBool | VChar _, TChar -> ()
  | _ -> craise __FILE__ __LINE__ span "Erroneous typing"

let check_typing_invariant (span : Meta.span) (ctx : eval_ctx) : unit =
  (* TODO: the type of aloans doens't make sense: they have a type
   * of the shape [& (mut) T] where they should have type [T]...
   * This messes a bit the type invariant checks when checking the
   * children. In order to isolate the problem (for future modifications)
   * we introduce this function, so that we can easily spot all the involved
   * places.
   * *)
  let aloan_get_expected_child_type (ty : ty) : ty =
    let _, ty, _ = ty_get_ref ty in
    ty
  in

  let visitor =
    object
      inherit [_] iter_eval_ctx as super
      method! visit_abs _ abs = super#visit_abs (Some abs) abs

      method! visit_EBinding info binder v =
        (* We also check that the regions are erased *)
        sanity_check __FILE__ __LINE__ (ty_is_ety v.ty) span;
        super#visit_EBinding info binder v

      method! visit_symbolic_value inside_abs v =
        (* Check that the types have regions *)
        sanity_check __FILE__ __LINE__ (ty_is_rty v.sv_ty) span;
        super#visit_symbolic_value inside_abs v

      method! visit_typed_value info tv =
        (* Check that the types have erased regions *)
        sanity_check __FILE__ __LINE__ (ty_is_ety tv.ty) span;
        (* Check the current pair (value, type) *)
        (match (tv.value, tv.ty) with
        | VLiteral cv, TLiteral ty -> check_literal_type span cv ty
        (* ADT case *)
        | VAdt av, TAdt (TAdtId def_id, generics) ->
            (* Retrieve the definition to check the variant id, the number of
             * parameters, etc. *)
            let def = ctx_lookup_type_decl ctx def_id in
            (* Check the number of parameters *)
            sanity_check __FILE__ __LINE__
              (List.length generics.regions = List.length def.generics.regions)
              span;
            sanity_check __FILE__ __LINE__
              (List.length generics.types = List.length def.generics.types)
              span;
            (* Check that the variant id is consistent *)
            (match (av.variant_id, def.kind) with
            | Some variant_id, Enum variants ->
                sanity_check __FILE__ __LINE__
                  (VariantId.to_int variant_id < List.length variants)
                  span
            | None, Struct _ -> ()
            | _ -> craise __FILE__ __LINE__ span "Erroneous typing");
            (* Check that the field types are correct *)
            let field_types =
              AssociatedTypes.type_decl_get_inst_norm_field_etypes span ctx def
                av.variant_id generics
            in
            let fields_with_types = List.combine av.field_values field_types in
            List.iter
              (fun ((v, ty) : typed_value * ty) ->
                sanity_check __FILE__ __LINE__ (v.ty = ty) span)
              fields_with_types
        (* Tuple case *)
        | VAdt av, TAdt (TTuple, generics) ->
            sanity_check __FILE__ __LINE__ (generics.regions = []) span;
            sanity_check __FILE__ __LINE__ (generics.const_generics = []) span;
            sanity_check __FILE__ __LINE__ (av.variant_id = None) span;
            (* Check that the fields have the proper values - and check that there
             * are as many fields as field types at the same time *)
            let fields_with_types =
              List.combine av.field_values generics.types
            in
            List.iter
              (fun ((v, ty) : typed_value * ty) ->
                sanity_check __FILE__ __LINE__ (v.ty = ty) span)
              fields_with_types
        (* Assumed type case *)
        | VAdt av, TAdt (TAssumed aty_id, generics) -> (
            sanity_check __FILE__ __LINE__ (av.variant_id = None) span;
            match
              ( aty_id,
                av.field_values,
                generics.regions,
                generics.types,
                generics.const_generics )
            with
            (* Box *)
            | TBox, [ inner_value ], [], [ inner_ty ], [] ->
                sanity_check __FILE__ __LINE__ (inner_value.ty = inner_ty) span
            | TArray, inner_values, _, [ inner_ty ], [ cg ] ->
                (* *)
                sanity_check __FILE__ __LINE__
                  (List.for_all
                     (fun (v : typed_value) -> v.ty = inner_ty)
                     inner_values)
                  span;
                (* The length is necessarily concrete *)
                let len =
                  (ValuesUtils.literal_as_scalar
                     (TypesUtils.const_generic_as_literal cg))
                    .value
                in
                sanity_check __FILE__ __LINE__
                  (Z.of_int (List.length inner_values) = len)
                  span
            | (TSlice | TStr), _, _, _, _ ->
                craise __FILE__ __LINE__ span "Unexpected"
            | _ -> craise __FILE__ __LINE__ span "Erroneous type")
        | VBottom, _ -> (* Nothing to check *) ()
        | VBorrow bc, TRef (_, ref_ty, rkind) -> (
            match (bc, rkind) with
            | VSharedBorrow bid, RShared | VReservedMutBorrow bid, RMut -> (
                (* Lookup the borrowed value to check it has the proper type *)
                let _, glc = lookup_loan span ek_all bid ctx in
                match glc with
                | Concrete (VSharedLoan (_, sv))
                | Abstract (ASharedLoan (_, sv, _)) ->
                    sanity_check __FILE__ __LINE__ (sv.ty = ref_ty) span
                | _ -> craise __FILE__ __LINE__ span "Inconsistent context")
            | VMutBorrow (_, bv), RMut ->
                sanity_check __FILE__ __LINE__
                  ((* Check that the borrowed value has the proper type *)
                   bv.ty = ref_ty)
                  span
            | _ -> craise __FILE__ __LINE__ span "Erroneous typing")
        | VLoan lc, ty -> (
            match lc with
            | VSharedLoan (_, sv) ->
                sanity_check __FILE__ __LINE__ (sv.ty = ty) span
            | VMutLoan bid -> (
                (* Lookup the borrowed value to check it has the proper type *)
                let glc = lookup_borrow span ek_all bid ctx in
                match glc with
                | Concrete (VMutBorrow (_, bv)) ->
                    sanity_check __FILE__ __LINE__ (bv.ty = ty) span
                | Abstract (AMutBorrow (_, sv)) ->
                    sanity_check __FILE__ __LINE__
                      (Substitute.erase_regions sv.ty = ty)
                      span
                | _ -> craise __FILE__ __LINE__ span "Inconsistent context"))
        | VSymbolic sv, ty ->
            let ty' = Substitute.erase_regions sv.sv_ty in
            sanity_check __FILE__ __LINE__ (ty' = ty) span
        | _ -> craise __FILE__ __LINE__ span "Erroneous typing");
        (* Continue exploring to inspect the subterms *)
        super#visit_typed_value info tv

      (* TODO: there is a lot of duplication with {!visit_typed_value}
       * which is quite annoying. There might be a way of factorizing
       * that by factorizing the definitions of value and avalue, but
       * the generation of visitors then doesn't work properly (TODO:
       * report that). Still, it is actually not that problematic
       * because this code shouldn't change a lot in the future,
       * so the cost of maintenance should be pretty low.
       * *)
      method! visit_typed_avalue info atv =
        (* Check that the types have regions *)
        sanity_check __FILE__ __LINE__ (ty_is_rty atv.ty) span;
        (* Check the current pair (value, type) *)
        (match (atv.value, atv.ty) with
        (* ADT case *)
        | AAdt av, TAdt (TAdtId def_id, generics) ->
            (* Retrieve the definition to check the variant id, the number of
             * parameters, etc. *)
            let def = ctx_lookup_type_decl ctx def_id in
            (* Check the number of parameters *)
            sanity_check __FILE__ __LINE__
              (List.length generics.regions = List.length def.generics.regions)
              span;
            sanity_check __FILE__ __LINE__
              (List.length generics.types = List.length def.generics.types)
              span;
            sanity_check __FILE__ __LINE__
              (List.length generics.const_generics
              = List.length def.generics.const_generics)
              span;
            (* Check that the variant id is consistent *)
            (match (av.variant_id, def.kind) with
            | Some variant_id, Enum variants ->
                sanity_check __FILE__ __LINE__
                  (VariantId.to_int variant_id < List.length variants)
                  span
            | None, Struct _ -> ()
            | _ -> craise __FILE__ __LINE__ span "Erroneous typing");
            (* Check that the field types are correct *)
            let field_types =
              AssociatedTypes.type_decl_get_inst_norm_field_rtypes span ctx def
                av.variant_id generics
            in
            let fields_with_types = List.combine av.field_values field_types in
            List.iter
              (fun ((v, ty) : typed_avalue * ty) ->
                sanity_check __FILE__ __LINE__ (v.ty = ty) span)
              fields_with_types
        (* Tuple case *)
        | AAdt av, TAdt (TTuple, generics) ->
            sanity_check __FILE__ __LINE__ (generics.regions = []) span;
            sanity_check __FILE__ __LINE__ (generics.const_generics = []) span;
            sanity_check __FILE__ __LINE__ (av.variant_id = None) span;
            (* Check that the fields have the proper values - and check that there
             * are as many fields as field types at the same time *)
            let fields_with_types =
              List.combine av.field_values generics.types
            in
            List.iter
              (fun ((v, ty) : typed_avalue * ty) ->
                sanity_check __FILE__ __LINE__ (v.ty = ty) span)
              fields_with_types
        (* Assumed type case *)
        | AAdt av, TAdt (TAssumed aty_id, generics) -> (
            sanity_check __FILE__ __LINE__ (av.variant_id = None) span;
            match
              ( aty_id,
                av.field_values,
                generics.regions,
                generics.types,
                generics.const_generics )
            with
            (* Box *)
            | TBox, [ boxed_value ], [], [ boxed_ty ], [] ->
                sanity_check __FILE__ __LINE__ (boxed_value.ty = boxed_ty) span
            | _ -> craise __FILE__ __LINE__ span "Erroneous type")
        | ABottom, _ -> (* Nothing to check *) ()
        | ABorrow bc, TRef (_, ref_ty, rkind) -> (
            match (bc, rkind) with
            | AMutBorrow (_, av), RMut ->
                (* Check that the child value has the proper type *)
                sanity_check __FILE__ __LINE__ (av.ty = ref_ty) span
            | ASharedBorrow bid, RShared -> (
                (* Lookup the borrowed value to check it has the proper type *)
                let _, glc = lookup_loan span ek_all bid ctx in
                match glc with
                | Concrete (VSharedLoan (_, sv))
                | Abstract (ASharedLoan (_, sv, _)) ->
                    sanity_check __FILE__ __LINE__
                      (sv.ty = Substitute.erase_regions ref_ty)
                      span
                | _ -> craise __FILE__ __LINE__ span "Inconsistent context")
            | AIgnoredMutBorrow (_opt_bid, av), RMut ->
                sanity_check __FILE__ __LINE__ (av.ty = ref_ty) span
            | ( AEndedIgnoredMutBorrow { given_back; child; given_back_span = _ },
                RMut ) ->
                sanity_check __FILE__ __LINE__ (given_back.ty = ref_ty) span;
                sanity_check __FILE__ __LINE__ (child.ty = ref_ty) span
            | AProjSharedBorrow _, RShared -> ()
            | _ -> craise __FILE__ __LINE__ span "Inconsistent context")
        | ALoan lc, aty -> (
            match lc with
            | AMutLoan (bid, child_av) | AIgnoredMutLoan (Some bid, child_av)
              -> (
                let borrowed_aty = aloan_get_expected_child_type aty in
                sanity_check __FILE__ __LINE__ (child_av.ty = borrowed_aty) span;
                (* Lookup the borrowed value to check it has the proper type *)
                let glc = lookup_borrow span ek_all bid ctx in
                match glc with
                | Concrete (VMutBorrow (_, bv)) ->
                    sanity_check __FILE__ __LINE__
                      (bv.ty = Substitute.erase_regions borrowed_aty)
                      span
                | Abstract (AMutBorrow (_, sv)) ->
                    sanity_check __FILE__ __LINE__
                      (Substitute.erase_regions sv.ty
                      = Substitute.erase_regions borrowed_aty)
                      span
                | _ -> craise __FILE__ __LINE__ span "Inconsistent context")
            | AIgnoredMutLoan (None, child_av) ->
                let borrowed_aty = aloan_get_expected_child_type aty in
                sanity_check __FILE__ __LINE__ (child_av.ty = borrowed_aty) span
            | ASharedLoan (_, sv, child_av) | AEndedSharedLoan (sv, child_av) ->
                let borrowed_aty = aloan_get_expected_child_type aty in
                sanity_check __FILE__ __LINE__
                  (sv.ty = Substitute.erase_regions borrowed_aty)
                  span;
                (* TODO: the type of aloans doesn't make sense, see above *)
                sanity_check __FILE__ __LINE__ (child_av.ty = borrowed_aty) span
            | AEndedMutLoan { given_back; child; given_back_span = _ }
            | AEndedIgnoredMutLoan { given_back; child; given_back_span = _ } ->
                let borrowed_aty = aloan_get_expected_child_type aty in
                sanity_check __FILE__ __LINE__
                  (given_back.ty = borrowed_aty)
                  span;
                sanity_check __FILE__ __LINE__ (child.ty = borrowed_aty) span
            | AIgnoredSharedLoan child_av ->
                sanity_check __FILE__ __LINE__
                  (child_av.ty = aloan_get_expected_child_type aty)
                  span)
        | ASymbolic aproj, ty -> (
            let ty1 = Substitute.erase_regions ty in
            match aproj with
            | AProjLoans (sv, _) ->
                let ty2 = Substitute.erase_regions sv.sv_ty in
                sanity_check __FILE__ __LINE__ (ty1 = ty2) span;
                (* Also check that the symbolic values contain regions of interest -
                 * otherwise they should have been reduced to [_] *)
                let abs = Option.get info in
                sanity_check __FILE__ __LINE__
                  (ty_has_regions_in_set abs.regions sv.sv_ty)
                  span
            | AProjBorrows (sv, proj_ty) ->
                let ty2 = Substitute.erase_regions sv.sv_ty in
                sanity_check __FILE__ __LINE__ (ty1 = ty2) span;
                (* Also check that the symbolic values contain regions of interest -
                 * otherwise they should have been reduced to [_] *)
                let abs = Option.get info in
                sanity_check __FILE__ __LINE__
                  (ty_has_regions_in_set abs.regions proj_ty)
                  span
            | AEndedProjLoans (_msv, given_back_ls) ->
                List.iter
                  (fun (_, proj) ->
                    match proj with
                    | AProjBorrows (_sv, ty') ->
                        sanity_check __FILE__ __LINE__ (ty' = ty) span
                    | AEndedProjBorrows _ | AIgnoredProjBorrows -> ()
                    | _ -> craise __FILE__ __LINE__ span "Unexpected")
                  given_back_ls
            | AEndedProjBorrows _ | AIgnoredProjBorrows -> ())
        | AIgnored, _ -> ()
        | _ ->
            log#ltrace
              (lazy
                ("Erroneous typing:" ^ "\n- raw value: " ^ show_typed_avalue atv
               ^ "\n- value: "
                ^ typed_avalue_to_string ~span:(Some span) ctx atv
                ^ "\n- type: " ^ ty_to_string ctx atv.ty));
            internal_error __FILE__ __LINE__ span);
        (* Continue exploring to inspect the subterms *)
        super#visit_typed_avalue info atv
    end
  in
  visitor#visit_eval_ctx (None : abs option) ctx

type proj_borrows_info = {
  abs_id : AbstractionId.id;
  regions : RegionId.Set.t;
  proj_ty : rty;  (** The regions shouldn't be erased *)
  as_shared_value : bool;  (** True if the value is below a shared borrow *)
}
[@@deriving show]

type proj_loans_info = { abs_id : AbstractionId.id; regions : RegionId.Set.t }
[@@deriving show]

type sv_info = {
  ty : rty;  (** The regions shouldn't be erased *)
  env_count : int;
  aproj_borrows : proj_borrows_info list;
  aproj_loans : proj_loans_info list;
}
[@@deriving show]

(** Check the invariants over the symbolic values.
    
    - a symbolic value can't be both in proj_borrows and in the concrete env
      (this is why we preemptively expand copyable symbolic values)
    - if a symbolic value contains regions: there is at most one occurrence
      of this value in the concrete env
    - if there is an aproj_borrows in the environment, there must also be a
      corresponding aproj_loans
    - aproj_loans are mutually disjoint
    - TODO: aproj_borrows are mutually disjoint
    - the union of the aproj_loans contains the aproj_borrows applied on the
      same symbolic values
 *)
let check_symbolic_values (span : Meta.span) (ctx : eval_ctx) : unit =
  (* Small utility *)
  let module M = SymbolicValueId.Map in
  let infos : sv_info M.t ref = ref M.empty in
  let lookup_info (sv : symbolic_value) : sv_info =
    match M.find_opt sv.sv_id !infos with
    | Some info -> info
    | None ->
        { ty = sv.sv_ty; env_count = 0; aproj_borrows = []; aproj_loans = [] }
  in
  let update_info (sv : symbolic_value) (info : sv_info) =
    infos := M.add sv.sv_id info !infos
  in
  let add_env_sv (sv : symbolic_value) : unit =
    let info = lookup_info sv in
    let info = { info with env_count = info.env_count + 1 } in
    update_info sv info
  in
  let add_aproj_borrows (sv : symbolic_value) abs_id regions proj_ty
      as_shared_value : unit =
    let info = lookup_info sv in
    let binfo = { abs_id; regions; proj_ty; as_shared_value } in
    let info = { info with aproj_borrows = binfo :: info.aproj_borrows } in
    update_info sv info
  in
  let add_aproj_loans (sv : symbolic_value) abs_id regions : unit =
    let info = lookup_info sv in
    let linfo = { abs_id; regions } in
    let info = { info with aproj_loans = linfo :: info.aproj_loans } in
    update_info sv info
  in
  (* Visitor *)
  let obj =
    object
      inherit [_] iter_eval_ctx as super
      method! visit_abs _ abs = super#visit_abs (Some abs) abs
      method! visit_VSymbolic _ sv = add_env_sv sv

      method! visit_abstract_shared_borrow abs asb =
        let abs = Option.get abs in
        match asb with
        | AsbBorrow _ -> ()
        | AsbProjReborrows (sv, proj_ty) ->
            add_aproj_borrows sv abs.abs_id abs.regions proj_ty true

      method! visit_aproj abs aproj =
        (let abs = Option.get abs in
         match aproj with
         | AProjLoans (sv, _) -> add_aproj_loans sv abs.abs_id abs.regions
         | AProjBorrows (sv, proj_ty) ->
             add_aproj_borrows sv abs.abs_id abs.regions proj_ty false
         | AEndedProjLoans _ | AEndedProjBorrows _ | AIgnoredProjBorrows -> ());
        super#visit_aproj abs aproj
    end
  in
  (* Collect the information *)
  obj#visit_eval_ctx None ctx;
  log#ldebug
    (lazy
      ("check_symbolic_values: collected information:\n"
      ^ SymbolicValueId.Map.to_string (Some "  ") show_sv_info !infos));
  (* Check *)
  let check_info _id info =
    (* TODO: check that:
     * - the borrows are mutually disjoint
     *)
    (* A symbolic value can't be both in the regular environment and inside
     * projectors of borrows in abstractions *)
    sanity_check __FILE__ __LINE__
      (info.env_count = 0 || info.aproj_borrows = [])
      span;
    (* A symbolic value containing borrows can't be duplicated (i.e., copied):
     * it must be expanded first *)
    if ty_has_borrows ctx.type_ctx.type_infos info.ty then
      sanity_check __FILE__ __LINE__ (info.env_count <= 1) span;
    (* A duplicated symbolic value is necessarily copyable *)
    sanity_check __FILE__ __LINE__
      (info.env_count <= 1 || ty_is_copyable info.ty)
      span;

    sanity_check __FILE__ __LINE__
      (info.aproj_borrows = [] || info.aproj_loans <> [])
      span;
    (* At the same time:
     * - check that the loans don't intersect
     * - compute the set of regions for which we project loans
     *)
    (* Check that the loan projectors contain the region projectors *)
    let loan_regions =
      List.fold_left
        (fun regions linfo ->
          let regions =
            RegionId.Set.fold
              (fun rid regions ->
                sanity_check __FILE__ __LINE__
                  (not (RegionId.Set.mem rid regions))
                  span;
                RegionId.Set.add rid regions)
              regions linfo.regions
          in
          regions)
        RegionId.Set.empty info.aproj_loans
    in
    (* Check that the union of the loan projectors contains the borrow projections. *)
    List.iter
      (fun binfo ->
        sanity_check __FILE__ __LINE__
          (projection_contains span info.ty loan_regions binfo.proj_ty
             binfo.regions)
          span)
      info.aproj_borrows;
    ()
  in

  M.iter check_info !infos

let check_invariants (span : Meta.span) (ctx : eval_ctx) : unit =
  if !Config.sanity_checks then (
    log#ldebug
      (lazy
        ("Checking invariants:\n" ^ eval_ctx_to_string ~span:(Some span) ctx));
    check_loans_borrows_relation_invariant span ctx;
    check_borrowed_values_invariant span ctx;
    check_typing_invariant span ctx;
    check_symbolic_values span ctx)
  else log#ldebug (lazy "Not checking invariants (check is not activated)")
