open Identifiers
open Types
open Values
open Expressions

module FunDefId = IdGen ()

module RegionGroupId = IdGen ()

type var = {
  index : VarId.id;  (** Unique variable identifier *)
  name : string option;
  var_ty : ety;
      (** The variable type - erased type, because variables are not used
       ** in function signatures: they are only used to declare the list of
       ** variables manipulated by a function body *)
}
[@@deriving show]
(** A variable, as used in a function definition *)

type assumed_fun_id = BoxNew | BoxDeref | BoxDerefMut | BoxFree
[@@deriving show]

type fun_id = Local of FunDefId.id | Assumed of assumed_fun_id
[@@deriving show]

type assertion = { cond : operand; expected : bool } [@@deriving show]

type ('id, 'r) g_region_group = {
  id : 'id;
  regions : 'r list;
  parents : 'id list;
}
[@@deriving show]
(** A group of regions.

    Results from a lifetime analysis: we group the regions with the same
    lifetime together, and compute the hierarchy between the regions.
    This is necessary to introduce the proper abstraction with the
    proper constraints, when evaluating a function call in symbolic mode.
*)

type ('r, 'id) g_region_groups = ('r, 'id) g_region_group list [@@deriving show]

type region_var_group = (RegionGroupId.id, RegionVarId.id) g_region_group
[@@deriving show]

type region_var_groups = (RegionGroupId.id, RegionVarId.id) g_region_groups
[@@deriving show]

type abs_region_group = (AbstractionId.id, RegionId.id) g_region_group
[@@deriving show]

type abs_region_groups = (AbstractionId.id, RegionId.id) g_region_groups
[@@deriving show]

type fun_sig = {
  region_params : region_var list;
  num_early_bound_regions : int;
  regions_hierarchy : region_var_groups;
  type_params : type_var list;
  inputs : sty list;
  output : sty;
}
[@@deriving show]
(** A function signature, as used when declaring functions *)

type inst_fun_sig = {
  regions_hierarchy : abs_region_groups;
  inputs : rty list;
  output : rty;
}
[@@deriving show]
(** A function signature, after instantiation *)

type call = {
  func : fun_id;
  region_params : erased_region list;
  type_params : ety list;
  args : operand list;
  dest : place;
}
[@@deriving show]

(** Ancestor for [typed_value] iter visitor *)
class ['self] iter_statement_base =
  object (_self : 'self)
    inherit [_] VisitorsRuntime.iter

    method visit_place : 'env -> place -> unit = fun _ _ -> ()

    method visit_rvalue : 'env -> rvalue -> unit = fun _ _ -> ()

    method visit_id : 'env -> VariantId.id -> unit = fun _ _ -> ()

    method visit_assertion : 'env -> assertion -> unit = fun _ _ -> ()

    method visit_operand : 'env -> operand -> unit = fun _ _ -> ()

    method visit_call : 'env -> call -> unit = fun _ _ -> ()

    method visit_integer_type : 'env -> integer_type -> unit = fun _ _ -> ()

    method visit_scalar_value : 'env -> scalar_value -> unit = fun _ _ -> ()
  end

(** Ancestor for [typed_value] map visitor *)
class ['self] map_statement_base =
  object (_self : 'self)
    inherit [_] VisitorsRuntime.map

    method visit_place : 'env -> place -> place = fun _ x -> x

    method visit_rvalue : 'env -> rvalue -> rvalue = fun _ x -> x

    method visit_id : 'env -> VariantId.id -> VariantId.id = fun _ x -> x

    method visit_assertion : 'env -> assertion -> assertion = fun _ x -> x

    method visit_operand : 'env -> operand -> operand = fun _ x -> x

    method visit_call : 'env -> call -> call = fun _ x -> x

    method visit_integer_type : 'env -> integer_type -> integer_type =
      fun _ x -> x

    method visit_scalar_value : 'env -> scalar_value -> scalar_value =
      fun _ x -> x
  end

type statement =
  | Assign of place * rvalue
  | FakeRead of place
  | SetDiscriminant of place * VariantId.id
  | Drop of place
  | Assert of assertion
  | Call of call
  | Panic
  | Return
  | Break of int
      (** Break to (outer) loop. The [int] identifies the loop to break to:
          * 0: break to the first outer loop (the current loop)
          * 1: break to the second outer loop
          * ...
          *)
  | Continue of int
      (** Continue to (outer) loop. The loop identifier works
          the same way as for [Break] *)
  | Nop
  | Sequence of statement * statement
  | Switch of operand * switch_targets
  | Loop of statement

and switch_targets =
  | If of statement * statement  (** Gives the "if" and "else" blocks *)
  | SwitchInt of integer_type * (scalar_value * statement) list * statement
      (** The targets for a switch over an integer are:
          - the list `(matched value, statement to execute)`
          - the "otherwise" statement.
          Also note that we precise the type of the integer (uint32, int64, etc.)
          which we switch on. *)
[@@deriving
  show,
    visitors
      {
        name = "iter_statement";
        variety = "iter";
        ancestors = [ "iter_statement_base" ];
        nude = true (* Don't inherit [VisitorsRuntime.iter] *);
        concrete = true;
      },
    visitors
      {
        name = "map_statement";
        variety = "map";
        ancestors = [ "map_statement_base" ];
        nude = true (* Don't inherit [VisitorsRuntime.iter] *);
        concrete = true;
      }]

type fun_def = {
  def_id : FunDefId.id;
  name : name;
  signature : fun_sig;
  divergent : bool;
  arg_count : int;
  locals : var list;
  body : statement;
}
[@@deriving show]
(** TODO: function definitions (and maybe type definitions in the future)
  * contain information like `divergent`. I wonder if this information should
  * be stored directly inside the definitions or inside separate maps/sets.
  * Of course, if everything is stored in separate maps/sets, nothing
  * prevents us from computing this info in Charon (and thus exporting directly
  * it with the type/function defs), in which case we just have to implement special
  * treatment when deserializing, to move the info to a separate map. *)
