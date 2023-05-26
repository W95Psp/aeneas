(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [external]: opaque function definitions *)
open primitivesLib divDefLib
open external_TypesTheory

val _ = new_theory "external_Opaque"


val _ = new_constant ("core_mem_swap_fwd",
  “:'t -> 't -> state -> (state # unit) result”)

val _ = new_constant ("core_mem_swap_back0",
  “:'t -> 't -> state -> state -> (state # 't) result”)

val _ = new_constant ("core_mem_swap_back1",
  “:'t -> 't -> state -> state -> (state # 't) result”)

val _ = new_constant ("core_num_nonzero_non_zero_u32_new_fwd",
  “:u32 -> state -> (state # core_num_nonzero_non_zero_u32_t option)
  result”)

val _ = new_constant ("core_option_option_unwrap_fwd",
  “:'t option -> state -> (state # 't) result”)

val _ = export_theory ()