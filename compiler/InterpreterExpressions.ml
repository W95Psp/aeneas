open Types
open Values
open Scalars
open Expressions
open Utils
open Contexts
open TypesUtils
open ValuesUtils
open SynthesizeSymbolic
open Cps
open InterpreterUtils
open InterpreterExpansion
open InterpreterPaths
open Errors

(** The local logger *)
let log = Logging.expressions_log

(** As long as there are symbolic values at a given place (potentially in subvalues)
    which contain borrows and are primitively copyable, expand them.
    
    We use this function before copying values.
    
    Note that the place should have been prepared so that there are no remaining
    loans.
*)
let expand_primitively_copyable_at_place (config : config) (span : Meta.span)
    (access : access_kind) (p : place) : cm_fun =
 fun ctx ->
  (* Small helper *)
  let rec expand : cm_fun =
   fun ctx ->
    let v = read_place span access p ctx in
    match
      find_first_primitively_copyable_sv_with_borrows ctx.type_ctx.type_infos v
    with
    | None -> (ctx, fun e -> e)
    | Some sv ->
        let ctx, cc =
          expand_symbolic_value_no_branching config span sv
            (Some (mk_mplace span p ctx))
            ctx
        in
        comp cc (expand ctx)
  in
  (* Apply *)
  expand ctx

(** Read a place.

    We check that the value *doesn't contain bottoms or reserved
    borrows*.
 *)
let read_place_check (span : Meta.span) (access : access_kind) (p : place)
    (ctx : eval_ctx) : typed_value =
  let v = read_place span access p ctx in
  (* Check that there are no bottoms in the value *)
  cassert __FILE__ __LINE__
    (not (bottom_in_value ctx.ended_regions v))
    span "There should be no bottoms in the value";
  (* Check that there are no reserved borrows in the value *)
  cassert __FILE__ __LINE__
    (not (reserved_in_value v))
    span "There should be no reserved borrows in the value";
  (* Return *)
  v

let access_rplace_reorganize_and_read (config : config) (span : Meta.span)
    (expand_prim_copy : bool) (access : access_kind) (p : place)
    (ctx : eval_ctx) : typed_value * eval_ctx * (eval_result -> eval_result) =
  (* Make sure we can evaluate the path *)
  let ctx, cc = update_ctx_along_read_place config span access p ctx in
  (* End the proper loans at the place itself *)
  let ctx, cc = comp cc (end_loans_at_place config span access p ctx) in
  (* Expand the copyable values which contain borrows (which are necessarily shared
   * borrows) *)
  let ctx, cc =
    comp cc
      (if expand_prim_copy then
         expand_primitively_copyable_at_place config span access p ctx
       else (ctx, fun e -> e))
  in
  (* Read the place - note that this checks that the value doesn't contain bottoms *)
  let ty_value = read_place_check span access p ctx in
  (* Compose *)
  (ty_value, ctx, cc)

let access_rplace_reorganize (config : config) (span : Meta.span)
    (expand_prim_copy : bool) (access : access_kind) (p : place) : cm_fun =
 fun ctx ->
  let _, ctx, f =
    access_rplace_reorganize_and_read config span expand_prim_copy access p ctx
  in
  (ctx, f)

(** Convert an operand constant operand value to a typed value *)
let literal_to_typed_value (span : Meta.span) (ty : literal_type) (cv : literal)
    : typed_value =
  (* Check the type while converting - we actually need some information
     * contained in the type *)
  log#ldebug
    (lazy
      ("literal_to_typed_value:" ^ "\n- cv: "
      ^ Print.Values.literal_to_string cv));
  match (ty, cv) with
  (* Scalar, boolean... *)
  | TBool, VBool v -> { value = VLiteral (VBool v); ty = TLiteral ty }
  | TChar, VChar v -> { value = VLiteral (VChar v); ty = TLiteral ty }
  | TInteger int_ty, VScalar v ->
      (* Check the type and the ranges *)
      sanity_check __FILE__ __LINE__ (int_ty = v.int_ty) span;
      sanity_check __FILE__ __LINE__ (check_scalar_value_in_range v) span;
      { value = VLiteral (VScalar v); ty = TLiteral ty }
  (* Remaining cases (invalid) *)
  | _, _ -> craise __FILE__ __LINE__ span "Improperly typed constant value"

(** Copy a value, and return the resulting value.

    Note that copying values might update the context. For instance, when
    copying shared borrows, we need to insert new shared borrows in the context.

    Also, this function is actually more general than it should be: it can be
    used to copy concrete ADT values, while ADT copy should be done through the
    Copy trait (i.e., by calling a dedicated function). This is why we added a
    parameter to control this copy ([allow_adt_copy]). Note that here by ADT we
    mean the user-defined ADTs (not tuples or assumed types).
 *)
let rec copy_value (span : Meta.span) (allow_adt_copy : bool) (config : config)
    (ctx : eval_ctx) (v : typed_value) : eval_ctx * typed_value =
  log#ldebug
    (lazy
      ("copy_value: "
      ^ typed_value_to_string ~span:(Some span) ctx v
      ^ "\n- context:\n"
      ^ eval_ctx_to_string ~span:(Some span) ctx));
  (* Remark: at some point we rewrote this function to use iterators, but then
   * we reverted the changes: the result was less clear actually. In particular,
   * the fact that we have exhaustive matches below makes very obvious the cases
   * in which we need to fail *)
  match v.value with
  | VLiteral _ -> (ctx, v)
  | VAdt av ->
      (* Sanity check *)
      (match v.ty with
      | TAdt (TAssumed TBox, _) ->
          exec_raise __FILE__ __LINE__ span
            "Can't copy an assumed value other than Option"
      | TAdt (TAdtId _, _) as ty ->
          sanity_check __FILE__ __LINE__
            (allow_adt_copy || ty_is_copyable ty)
            span
      | TAdt (TTuple, _) -> () (* Ok *)
      | TAdt
          ( TAssumed (TSlice | TArray),
            {
              regions = [];
              types = [ ty ];
              const_generics = [];
              trait_refs = [];
            } ) ->
          exec_assert __FILE__ __LINE__ (ty_is_copyable ty) span
            "The type is not primitively copyable"
      | _ -> exec_raise __FILE__ __LINE__ span "Unreachable");
      let ctx, fields =
        List.fold_left_map
          (copy_value span allow_adt_copy config)
          ctx av.field_values
      in
      (ctx, { v with value = VAdt { av with field_values = fields } })
  | VBottom -> exec_raise __FILE__ __LINE__ span "Can't copy ⊥"
  | VBorrow bc -> (
      (* We can only copy shared borrows *)
      match bc with
      | VSharedBorrow bid ->
          (* We need to create a new borrow id for the copied borrow, and
           * update the context accordingly *)
          let bid' = fresh_borrow_id () in
          let ctx = InterpreterBorrows.reborrow_shared span bid bid' ctx in
          (ctx, { v with value = VBorrow (VSharedBorrow bid') })
      | VMutBorrow (_, _) ->
          exec_raise __FILE__ __LINE__ span "Can't copy a mutable borrow"
      | VReservedMutBorrow _ ->
          exec_raise __FILE__ __LINE__ span "Can't copy a reserved mut borrow")
  | VLoan lc -> (
      (* We can only copy shared loans *)
      match lc with
      | VMutLoan _ ->
          exec_raise __FILE__ __LINE__ span "Can't copy a mutable loan"
      | VSharedLoan (_, sv) ->
          (* We don't copy the shared loan: only the shared value inside *)
          copy_value span allow_adt_copy config ctx sv)
  | VSymbolic sp ->
      (* We can copy only if the type is "primitively" copyable.
       * Note that in the general case, copy is a trait: copying values
       * thus requires calling the proper function. Here, we copy values
       * for very simple types such as integers, shared borrows, etc. *)
      cassert __FILE__ __LINE__
        (ty_is_copyable (Substitute.erase_regions sp.sv_ty))
        span "Not primitively copyable";
      (* If the type is copyable, we simply return the current value. Side
       * remark: what is important to look at when copying symbolic values
       * is symbolic expansion. The important subcase is the expansion of shared
       * borrows: when doing so, every occurrence of the same symbolic value
       * must use a fresh borrow id. *)
      (ctx, v)

(** Reorganize the environment in preparation for the evaluation of an operand.

    Evaluating an operand requires reorganizing the environment to get access
    to a given place (by ending borrows, expanding symbolic values...) then
    applying the operand operation (move, copy, etc.).
    
    Sometimes, we want to decouple the two operations.
    Consider the following example:
    {[
      context = {
        x -> shared_borrow l0
        y -> shared_loan {l0} v
      }

      dest <- f(move x, move y);
      ...
    ]}

    Because of the way {!end_borrow} is implemented, when giving back the borrow
    [l0] upon evaluating [move y], if we have already moved the value of x,
    we won't notice that [shared_borrow l0] has disappeared from the environment
    (it has been moved and not assigned yet, and so is hanging in "thin air").
    
    By first "preparing" the operands evaluation, we make sure no such thing
    happens. To be more precise, we make sure all the updates to borrows triggered
    by access *and* move operations have already been applied.

    Rem.: in the formalization, we always have an explicit "reorganization" step
    in the rule premises, before the actual operand evaluation, that allows to
    reorganize the environment so that it satisfies the proper conditions. This
    function's role is to do the reorganization.
    
    Rem.: doing this is actually not completely necessary because when
    generating MIR, rustc introduces intermediate assignments for all the function
    parameters. Still, it is better for soundness purposes, and corresponds to
    what we do in the formalization (because we don't enforce the same constraints
    as MIR in the formalization).
 *)
let prepare_eval_operand_reorganize (config : config) (span : Meta.span)
    (op : operand) : cm_fun =
 fun ctx ->
  match op with
  | Constant _ ->
      (* No need to reorganize the context *)
      (ctx, fun e -> e)
  | Copy p ->
      (* Access the value *)
      let access = Read in
      (* Expand the symbolic values, if necessary *)
      let expand_prim_copy = true in
      access_rplace_reorganize config span expand_prim_copy access p ctx
  | Move p ->
      (* Access the value *)
      let access = Move in
      let expand_prim_copy = false in
      access_rplace_reorganize config span expand_prim_copy access p ctx

(** Evaluate an operand, without reorganizing the context before *)
let eval_operand_no_reorganize (config : config) (span : Meta.span)
    (op : operand) (ctx : eval_ctx) :
    typed_value * eval_ctx * (eval_result -> eval_result) =
  (* Debug *)
  log#ldebug
    (lazy
      ("eval_operand_no_reorganize: op: " ^ operand_to_string ctx op
     ^ "\n- ctx:\n"
      ^ eval_ctx_to_string ~span:(Some span) ctx
      ^ "\n"));
  (* Evaluate *)
  match op with
  | Constant cv -> (
      match cv.value with
      | CLiteral lit ->
          ( literal_to_typed_value span (ty_as_literal cv.ty) lit,
            ctx,
            fun e -> e )
      | CTraitConst (trait_ref, const_name) ->
          let ctx0 = ctx in
          (* Simply introduce a fresh symbolic value *)
          let ty = cv.ty in
          let v = mk_fresh_symbolic_typed_value span ty in
          (* Wrap the generated expression *)
          let cf e =
            match e with
            | None -> None
            | Some e ->
                Some
                  (SymbolicAst.IntroSymbolic
                     ( ctx0,
                       None,
                       value_as_symbolic span v.value,
                       SymbolicAst.VaTraitConstValue (trait_ref, const_name),
                       e ))
          in
          (v, ctx, cf)
      | CVar vid ->
          let ctx0 = ctx in
          (* In concrete mode: lookup the const generic value.
             In symbolic mode: introduce a fresh symbolic value.

             We have nothing to do: the value is copyable, so we can freely
             duplicate it.
          *)
          let ctx, cv =
            let cv = ctx_lookup_const_generic_value ctx vid in
            match config.mode with
            | ConcreteMode ->
                (* Copy the value - this is more of a sanity check *)
                let allow_adt_copy = false in
                copy_value span allow_adt_copy config ctx cv
            | SymbolicMode ->
                (* We use the looked up value only for its type *)
                let v = mk_fresh_symbolic_typed_value span cv.ty in
                (ctx, v)
          in
          (* We have to wrap the generated expression *)
          let cf e =
            match e with
            | None -> None
            | Some e ->
                (* If we are synthesizing a symbolic AST, it means that we are in symbolic
                   mode: the value of the const generic is necessarily symbolic. *)
                sanity_check __FILE__ __LINE__ (is_symbolic cv.value) span;
                (* *)
                Some
                  (SymbolicAst.IntroSymbolic
                     ( ctx0,
                       None,
                       value_as_symbolic span cv.value,
                       SymbolicAst.VaCgValue vid,
                       e ))
          in
          (cv, ctx, cf)
      | CFnPtr _ ->
          craise __FILE__ __LINE__ span
            "Function pointers are not supported yet")
  | Copy p ->
      (* Access the value *)
      let access = Read in
      let v = read_place_check span access p ctx in
      (* Sanity checks *)
      exec_assert __FILE__ __LINE__
        (not (bottom_in_value ctx.ended_regions v))
        span "Can not copy a value containing bottom";
      sanity_check __FILE__ __LINE__
        (Option.is_none
           (find_first_primitively_copyable_sv_with_borrows
              ctx.type_ctx.type_infos v))
        span;
      (* Copy the value *)
      let allow_adt_copy = false in
      let ctx, v = copy_value span allow_adt_copy config ctx v in
      (v, ctx, fun e -> e)
  | Move p ->
      (* Access the value *)
      let access = Move in
      let v = read_place_check span access p ctx in
      (* Check that there are no bottoms in the value we are about to move *)
      exec_assert __FILE__ __LINE__
        (not (bottom_in_value ctx.ended_regions v))
        span "There should be no bottoms in the value we are about to move";
      (* Move the value *)
      let bottom : typed_value = { value = VBottom; ty = v.ty } in
      let ctx = write_place span access p bottom ctx in
      (v, ctx, fun e -> e)

let eval_operand (config : config) (span : Meta.span) (op : operand)
    (ctx : eval_ctx) : typed_value * eval_ctx * (eval_result -> eval_result) =
  (* Debug *)
  log#ldebug
    (lazy
      ("eval_operand: op: " ^ operand_to_string ctx op ^ "\n- ctx:\n"
      ^ eval_ctx_to_string ~span:(Some span) ctx
      ^ "\n"));
  (* We reorganize the context, then evaluate the operand *)
  let ctx, cc = prepare_eval_operand_reorganize config span op ctx in
  comp2 cc (eval_operand_no_reorganize config span op ctx)

(** Small utility.

    See [prepare_eval_operand_reorganize].
 *)
let prepare_eval_operands_reorganize (config : config) (span : Meta.span)
    (ops : operand list) : cm_fun =
  fold_left_apply_continuation (prepare_eval_operand_reorganize config span) ops

(** Evaluate several operands. *)
let eval_operands (config : config) (span : Meta.span) (ops : operand list)
    (ctx : eval_ctx) :
    typed_value list * eval_ctx * (eval_result -> eval_result) =
  (* Prepare the operands *)
  let ctx, cc = prepare_eval_operands_reorganize config span ops ctx in
  (* Evaluate the operands *)
  comp2 cc
    (map_apply_continuation (eval_operand_no_reorganize config span) ops ctx)

let eval_two_operands (config : config) (span : Meta.span) (op1 : operand)
    (op2 : operand) (ctx : eval_ctx) :
    (typed_value * typed_value) * eval_ctx * (eval_result -> eval_result) =
  let res, ctx, cc = eval_operands config span [ op1; op2 ] ctx in
  let res =
    match res with
    | [ v1; v2 ] -> (v1, v2)
    | _ -> craise __FILE__ __LINE__ span "Unreachable"
  in
  (res, ctx, cc)

let eval_unary_op_concrete (config : config) (span : Meta.span) (unop : unop)
    (op : operand) (ctx : eval_ctx) :
    (typed_value, eval_error) result * eval_ctx * (eval_result -> eval_result) =
  (* Evaluate the operand *)
  let v, ctx, cc = eval_operand config span op ctx in
  (* Apply the unop *)
  let r =
    match (unop, v.value) with
    | Not, VLiteral (VBool b) -> Ok { v with value = VLiteral (VBool (not b)) }
    | Neg, VLiteral (VScalar sv) -> (
        let i = Z.neg sv.value in
        match mk_scalar sv.int_ty i with
        | Error _ -> Error EPanic
        | Ok sv -> Ok { v with value = VLiteral (VScalar sv) })
    | ( Cast (CastScalar (TInteger src_ty, TInteger tgt_ty)),
        VLiteral (VScalar sv) ) -> (
        (* Cast between integers *)
        sanity_check __FILE__ __LINE__ (src_ty = sv.int_ty) span;
        let i = sv.value in
        match mk_scalar tgt_ty i with
        | Error _ -> Error EPanic
        | Ok sv ->
            let ty = TLiteral (TInteger tgt_ty) in
            let value = VLiteral (VScalar sv) in
            Ok { ty; value })
    | Cast (CastScalar (TBool, TInteger tgt_ty)), VLiteral (VBool sv) -> (
        (* Cast bool -> int *)
        let i = Z.of_int (if sv then 1 else 0) in
        match mk_scalar tgt_ty i with
        | Error _ -> Error EPanic
        | Ok sv ->
            let ty = TLiteral (TInteger tgt_ty) in
            let value = VLiteral (VScalar sv) in
            Ok { ty; value })
    | Cast (CastScalar (TInteger _, TBool)), VLiteral (VScalar sv) ->
        (* Cast int -> bool *)
        let b =
          if Z.of_int 0 = sv.value then false
          else if Z.of_int 1 = sv.value then true
          else
            exec_raise __FILE__ __LINE__ span
              "Conversion from int to bool: out of range"
        in
        let value = VLiteral (VBool b) in
        let ty = TLiteral TBool in
        Ok { ty; value }
    | _ -> exec_raise __FILE__ __LINE__ span "Invalid input for unop"
  in
  (r, ctx, cc)

let eval_unary_op_symbolic (config : config) (span : Meta.span) (unop : unop)
    (op : operand) (ctx : eval_ctx) :
    (typed_value, eval_error) result * eval_ctx * (eval_result -> eval_result) =
  (* Evaluate the operand *)
  let v, ctx, cc = eval_operand config span op ctx in
  (* Generate a fresh symbolic value to store the result *)
  let res_sv_id = fresh_symbolic_value_id () in
  let res_sv_ty =
    match (unop, v.ty) with
    | Not, (TLiteral TBool as lty) -> lty
    | Neg, (TLiteral (TInteger _) as lty) -> lty
    | Cast (CastScalar (_, tgt_ty)), _ -> TLiteral tgt_ty
    | _ -> exec_raise __FILE__ __LINE__ span "Invalid input for unop"
  in
  let res_sv = { sv_id = res_sv_id; sv_ty = res_sv_ty } in
  (* Compute the result *)
  let res = Ok (mk_typed_value_from_symbolic_value res_sv) in
  (* Synthesize the symbolic AST *)
  let cc =
    cc_comp cc
      (synthesize_unary_op ctx unop v
         (mk_opt_place_from_op span op ctx)
         res_sv None)
  in
  (res, ctx, cc)

let eval_unary_op (config : config) (span : Meta.span) (unop : unop)
    (op : operand) (ctx : eval_ctx) :
    (typed_value, eval_error) result * eval_ctx * (eval_result -> eval_result) =
  match config.mode with
  | ConcreteMode -> eval_unary_op_concrete config span unop op ctx
  | SymbolicMode -> eval_unary_op_symbolic config span unop op ctx

(** Small helper for [eval_binary_op_concrete]: computes the result of applying
    the binop *after* the operands have been successfully evaluated
 *)
let eval_binary_op_concrete_compute (span : Meta.span) (binop : binop)
    (v1 : typed_value) (v2 : typed_value) : (typed_value, eval_error) result =
  (* Equality check binops (Eq, Ne) accept values from a wide variety of types.
   * The remaining binops only operate on scalars. *)
  if binop = Eq || binop = Ne then (
    (* Equality operations *)
    exec_assert __FILE__ __LINE__ (v1.ty = v2.ty) span
      "The arguments given to the binop don't have the same type";
    (* Equality/inequality check is primitive only for a subset of types *)
    exec_assert __FILE__ __LINE__ (ty_is_copyable v1.ty) span
      "Type is not primitively copyable";
    let b = v1 = v2 in
    Ok { value = VLiteral (VBool b); ty = TLiteral TBool })
  else
    (* For the non-equality operations, the input values are necessarily scalars *)
    match (v1.value, v2.value) with
    | VLiteral (VScalar sv1), VLiteral (VScalar sv2) -> (
        (* There are binops which require the two operands to have the same
           type, and binops for which it is not the case.
           There are also binops which return booleans, and binops which
           return integers.
        *)
        match binop with
        | Lt | Le | Ge | Gt ->
            (* The two operands must have the same type and the result is a boolean *)
            sanity_check __FILE__ __LINE__ (sv1.int_ty = sv2.int_ty) span;
            let b =
              match binop with
              | Lt -> Z.lt sv1.value sv2.value
              | Le -> Z.leq sv1.value sv2.value
              | Ge -> Z.geq sv1.value sv2.value
              | Gt -> Z.gt sv1.value sv2.value
              | Div | Rem | Add | Sub | Mul | BitXor | BitAnd | BitOr | Shl
              | Shr | Ne | Eq | CheckedAdd | CheckedSub | CheckedMul ->
                  craise __FILE__ __LINE__ span "Unreachable"
            in
            Ok
              ({ value = VLiteral (VBool b); ty = TLiteral TBool }
                : typed_value)
        | Div | Rem | Add | Sub | Mul | BitXor | BitAnd | BitOr -> (
            (* The two operands must have the same type and the result is an integer *)
            sanity_check __FILE__ __LINE__ (sv1.int_ty = sv2.int_ty) span;
            let res =
              match binop with
              | Div ->
                  if sv2.value = Z.zero then Error ()
                  else mk_scalar sv1.int_ty (Z.div sv1.value sv2.value)
              | Rem ->
                  (* See [https://github.com/ocaml/Zarith/blob/master/z.mli] *)
                  if sv2.value = Z.zero then Error ()
                  else mk_scalar sv1.int_ty (Z.rem sv1.value sv2.value)
              | Add -> mk_scalar sv1.int_ty (Z.add sv1.value sv2.value)
              | Sub -> mk_scalar sv1.int_ty (Z.sub sv1.value sv2.value)
              | Mul -> mk_scalar sv1.int_ty (Z.mul sv1.value sv2.value)
              | BitXor -> raise Unimplemented
              | BitAnd -> raise Unimplemented
              | BitOr -> raise Unimplemented
              | Lt | Le | Ge | Gt | Shl | Shr | Ne | Eq | CheckedAdd
              | CheckedSub | CheckedMul ->
                  craise __FILE__ __LINE__ span "Unreachable"
            in
            match res with
            | Error _ -> Error EPanic
            | Ok sv ->
                Ok
                  {
                    value = VLiteral (VScalar sv);
                    ty = TLiteral (TInteger sv1.int_ty);
                  })
        | Shl | Shr | CheckedAdd | CheckedSub | CheckedMul ->
            craise __FILE__ __LINE__ span "Unimplemented binary operation"
        | Ne | Eq -> craise __FILE__ __LINE__ span "Unreachable")
    | _ -> craise __FILE__ __LINE__ span "Invalid inputs for binop"

let eval_binary_op_concrete (config : config) (span : Meta.span) (binop : binop)
    (op1 : operand) (op2 : operand) (ctx : eval_ctx) :
    (typed_value, eval_error) result * eval_ctx * (eval_result -> eval_result) =
  (* Evaluate the operands *)
  let (v1, v2), ctx, cc = eval_two_operands config span op1 op2 ctx in
  (* Compute the result of the binop *)
  let r = eval_binary_op_concrete_compute span binop v1 v2 in
  (* Return *)
  (r, ctx, cc)

let eval_binary_op_symbolic (config : config) (span : Meta.span) (binop : binop)
    (op1 : operand) (op2 : operand) (ctx : eval_ctx) :
    (typed_value, eval_error) result * eval_ctx * (eval_result -> eval_result) =
  (* Evaluate the operands *)
  let (v1, v2), ctx, cc = eval_two_operands config span op1 op2 ctx in
  (* Generate a fresh symbolic value to store the result *)
  let res_sv_id = fresh_symbolic_value_id () in
  let res_sv_ty =
    if binop = Eq || binop = Ne then (
      (* Equality operations *)
      sanity_check __FILE__ __LINE__ (v1.ty = v2.ty) span;
      (* Equality/inequality check is primitive only for a subset of types *)
      exec_assert __FILE__ __LINE__ (ty_is_copyable v1.ty) span
        "The type is not primitively copyable";
      TLiteral TBool)
    else
      (* Other operations: input types are integers *)
      match (v1.ty, v2.ty) with
      | TLiteral (TInteger int_ty1), TLiteral (TInteger int_ty2) -> (
          match binop with
          | Lt | Le | Ge | Gt ->
              sanity_check __FILE__ __LINE__ (int_ty1 = int_ty2) span;
              TLiteral TBool
          | Div | Rem | Add | Sub | Mul | BitXor | BitAnd | BitOr ->
              sanity_check __FILE__ __LINE__ (int_ty1 = int_ty2) span;
              TLiteral (TInteger int_ty1)
          (* These return `(int, bool)` which isn't a literal type *)
          | CheckedAdd | CheckedSub | CheckedMul ->
              craise __FILE__ __LINE__ span
                "Checked operations are not implemented"
          | Shl | Shr ->
              (* The number of bits can be of a different integer type
                 than the operand *)
              TLiteral (TInteger int_ty1)
          | Ne | Eq -> craise __FILE__ __LINE__ span "Unreachable")
      | _ -> craise __FILE__ __LINE__ span "Invalid inputs for binop"
  in
  let res_sv = { sv_id = res_sv_id; sv_ty = res_sv_ty } in
  let v = mk_typed_value_from_symbolic_value res_sv in
  (* Synthesize the symbolic AST *)
  let p1 = mk_opt_place_from_op span op1 ctx in
  let p2 = mk_opt_place_from_op span op2 ctx in
  let cc =
    cc_comp cc (synthesize_binary_op ctx binop v1 p1 v2 p2 res_sv None)
  in
  (* Compose and apply *)
  (Ok v, ctx, cc)

let eval_binary_op (config : config) (span : Meta.span) (binop : binop)
    (op1 : operand) (op2 : operand) (ctx : eval_ctx) :
    (typed_value, eval_error) result * eval_ctx * (eval_result -> eval_result) =
  match config.mode with
  | ConcreteMode -> eval_binary_op_concrete config span binop op1 op2 ctx
  | SymbolicMode -> eval_binary_op_symbolic config span binop op1 op2 ctx

(** Evaluate an rvalue which creates a reference (i.e., an rvalue which is
    `&p` or `&mut p` or `&two-phase p`) *)
let eval_rvalue_ref (config : config) (span : Meta.span) (p : place)
    (bkind : borrow_kind) (ctx : eval_ctx) :
    typed_value * eval_ctx * (eval_result -> eval_result) =
  match bkind with
  | BShared | BTwoPhaseMut | BShallow ->
      (* **REMARK**: we initially treated shallow borrows like shared borrows.
         In practice this restricted the behaviour too much, so for now we
         forbid them and remove them in the prepasses (see the comments there
         as to why this is sound).
      *)
      sanity_check __FILE__ __LINE__ (bkind <> BShallow) span;

      (* Access the value *)
      let access =
        match bkind with
        | BShared | BShallow -> Read
        | BTwoPhaseMut -> Write
        | _ -> craise __FILE__ __LINE__ span "Unreachable"
      in

      let expand_prim_copy = false in
      let v, ctx, cc =
        access_rplace_reorganize_and_read config span expand_prim_copy access p
          ctx
      in
      (* Generate the fresh borrow id *)
      let bid = fresh_borrow_id () in
      (* Compute the loan value, with which to replace the value at place p *)
      let nv =
        match v.value with
        | VLoan (VSharedLoan (bids, sv)) ->
            (* Shared loan: insert the new borrow id *)
            let bids1 = BorrowId.Set.add bid bids in
            { v with value = VLoan (VSharedLoan (bids1, sv)) }
        | _ ->
            (* Not a shared loan: add a wrapper *)
            let v' = VLoan (VSharedLoan (BorrowId.Set.singleton bid, v)) in
            { v with value = v' }
      in
      (* Update the value in the context to replace it with the loan *)
      let ctx = write_place span access p nv ctx in
      (* Compute the rvalue - simply a shared borrow with the fresh id.
       * Note that the reference is *mutable* if we do a two-phase borrow *)
      let ref_kind =
        match bkind with
        | BShared | BShallow -> RShared
        | BTwoPhaseMut -> RMut
        | _ -> craise __FILE__ __LINE__ span "Unreachable"
      in
      let rv_ty = TRef (RErased, v.ty, ref_kind) in
      let bc =
        match bkind with
        | BShared | BShallow ->
            (* See the remark at the beginning of the match branch: we
               handle shallow borrows like shared borrows *)
            VSharedBorrow bid
        | BTwoPhaseMut -> VReservedMutBorrow bid
        | _ -> craise __FILE__ __LINE__ span "Unreachable"
      in
      let rv : typed_value = { value = VBorrow bc; ty = rv_ty } in
      (* Return *)
      (rv, ctx, cc)
  | BMut ->
      (* Access the value *)
      let access = Write in
      let expand_prim_copy = false in
      let v, ctx, cc =
        access_rplace_reorganize_and_read config span expand_prim_copy access p
          ctx
      in
      (* Compute the rvalue - wrap the value in a mutable borrow with a fresh id *)
      let bid = fresh_borrow_id () in
      let rv_ty = TRef (RErased, v.ty, RMut) in
      let rv : typed_value =
        { value = VBorrow (VMutBorrow (bid, v)); ty = rv_ty }
      in
      (* Compute the loan value with which to replace the value at place p *)
      let nv = { v with value = VLoan (VMutLoan bid) } in
      (* Update the value in the context to replace it with the loan *)
      let ctx = write_place span access p nv ctx in
      (* Return *)
      (rv, ctx, cc)

let eval_rvalue_aggregate (config : config) (span : Meta.span)
    (aggregate_kind : aggregate_kind) (ops : operand list) (ctx : eval_ctx) :
    typed_value * eval_ctx * (eval_result -> eval_result) =
  (* Evaluate the operands *)
  let values, ctx, cc = eval_operands config span ops ctx in
  (* Compute the value *)
  let v, cf_compute =
    (* Match on the aggregate kind *)
    match aggregate_kind with
    | AggregatedAdt (type_id, opt_variant_id, generics) -> (
        match type_id with
        | TTuple ->
            let tys = List.map (fun (v : typed_value) -> v.ty) values in
            let v = VAdt { variant_id = None; field_values = values } in
            let generics = mk_generic_args [] tys [] [] in
            let ty = TAdt (TTuple, generics) in
            let aggregated : typed_value = { value = v; ty } in
            (aggregated, fun e -> e)
        | TAdtId def_id ->
            (* Sanity checks *)
            let type_decl = ctx_lookup_type_decl ctx def_id in
            sanity_check __FILE__ __LINE__
              (List.length type_decl.generics.regions
              = List.length generics.regions)
              span;
            let expected_field_types =
              AssociatedTypes.ctx_adt_get_inst_norm_field_etypes span ctx def_id
                opt_variant_id generics
            in
            sanity_check __FILE__ __LINE__
              (expected_field_types
              = List.map (fun (v : typed_value) -> v.ty) values)
              span;
            (* Construct the value *)
            let av : adt_value =
              { variant_id = opt_variant_id; field_values = values }
            in
            let aty = TAdt (TAdtId def_id, generics) in
            let aggregated : typed_value = { value = VAdt av; ty = aty } in
            (* Call the continuation *)
            (aggregated, fun e -> e)
        | TAssumed _ -> craise __FILE__ __LINE__ span "Unreachable")
    | AggregatedArray (ety, cg) ->
        (* Sanity check: all the values have the proper type *)
        sanity_check __FILE__ __LINE__
          (List.for_all (fun (v : typed_value) -> v.ty = ety) values)
          span;
        (* Sanity check: the number of values is consistent with the length *)
        let len = (literal_as_scalar (const_generic_as_literal cg)).value in
        sanity_check __FILE__ __LINE__
          (len = Z.of_int (List.length values))
          span;
        let generics = TypesUtils.mk_generic_args [] [ ety ] [ cg ] [] in
        let ty = TAdt (TAssumed TArray, generics) in
        (* In order to generate a better AST, we introduce a symbolic
           value equal to the array. The reason is that otherwise, the
           array we introduce here might be duplicated in the generated
           code: by introducing a symbolic value we introduce a let-binding
           in the generated code. *)
        let saggregated = mk_fresh_symbolic_typed_value span ty in
        (* Update the symbolic ast *)
        let cf e =
          match e with
          | None -> None
          | Some e ->
              (* Introduce the symbolic value in the AST *)
              let sv = ValuesUtils.value_as_symbolic span saggregated.value in
              Some
                (SymbolicAst.IntroSymbolic (ctx, None, sv, VaArray values, e))
        in
        (saggregated, cf)
    | AggregatedClosure _ ->
        craise __FILE__ __LINE__ span "Closures are not supported yet"
  in
  (v, ctx, cc_comp cc cf_compute)

let eval_rvalue_not_global (config : config) (span : Meta.span)
    (rvalue : rvalue) (ctx : eval_ctx) :
    (typed_value, eval_error) result * eval_ctx * (eval_result -> eval_result) =
  log#ldebug (lazy "eval_rvalue");
  (* Small helper *)
  let wrap_in_result (v, ctx, cc) = (Ok v, ctx, cc) in
  (* Delegate to the proper auxiliary function *)
  match rvalue with
  | Use op -> wrap_in_result (eval_operand config span op ctx)
  | RvRef (p, bkind) -> wrap_in_result (eval_rvalue_ref config span p bkind ctx)
  | UnaryOp (unop, op) -> eval_unary_op config span unop op ctx
  | BinaryOp (binop, op1, op2) -> eval_binary_op config span binop op1 op2 ctx
  | Aggregate (aggregate_kind, ops) ->
      wrap_in_result (eval_rvalue_aggregate config span aggregate_kind ops ctx)
  | Discriminant _ ->
      craise __FILE__ __LINE__ span
        "Unreachable: discriminant reads should have been eliminated from the \
         AST"
  | Global _ -> craise __FILE__ __LINE__ span "Unreachable"

let eval_fake_read (config : config) (span : Meta.span) (p : place) : cm_fun =
 fun ctx ->
  let expand_prim_copy = false in
  let v, ctx, cc =
    access_rplace_reorganize_and_read config span expand_prim_copy Read p ctx
  in
  cassert __FILE__ __LINE__
    (not (bottom_in_value ctx.ended_regions v))
    span "Fake read: the value contains bottom";
  (ctx, cc)
