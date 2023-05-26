(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [betree_main]: opaque function definitions *)
open primitivesLib divDefLib
open betreeMain_TypesTheory

val _ = new_theory "betreeMain_Opaque"


val _ = new_constant ("betree_utils_load_internal_node_fwd",
  “:u64 -> state -> (state # (u64 # betree_message_t) betree_list_t)
  result”)

val _ = new_constant ("betree_utils_store_internal_node_fwd",
  “:u64 -> (u64 # betree_message_t) betree_list_t -> state -> (state # unit)
  result”)

val _ = new_constant ("betree_utils_load_leaf_node_fwd",
  “:u64 -> state -> (state # (u64 # u64) betree_list_t) result”)

val _ = new_constant ("betree_utils_store_leaf_node_fwd",
  “:u64 -> (u64 # u64) betree_list_t -> state -> (state # unit) result”)

val _ = new_constant ("core_option_option_unwrap_fwd",
  “:'t option -> state -> (state # 't) result”)

val _ = export_theory ()