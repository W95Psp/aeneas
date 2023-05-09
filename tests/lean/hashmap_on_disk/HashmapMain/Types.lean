-- THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS
-- [hashmap_main]: type definitions
import Base.Primitives

/- [hashmap_main::hashmap::List] -/
inductive hashmap_list_t (T : Type) :=
| Cons : Usize -> T -> hashmap_list_t T -> hashmap_list_t T
| Nil : hashmap_list_t T

/- [hashmap_main::hashmap::HashMap] -/
structure hashmap_hash_map_t (T : Type) where
  hashmap_hash_map_num_entries : Usize
  hashmap_hash_map_max_load_factor : (Usize × Usize)
  hashmap_hash_map_max_load : Usize
  hashmap_hash_map_slots : Vec (hashmap_list_t T)

/- The state type used in the state-error monad -/
axiom State : Type

