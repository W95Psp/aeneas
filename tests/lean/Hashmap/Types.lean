-- THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS
-- [hashmap]: type definitions
import Base
open Primitives

namespace hashmap

/- [hashmap::List]
   Source: 'tests/src/hashmap.rs', lines 19:0-19:16 -/
inductive List (T : Type) :=
| Cons : Usize → T → List T → List T
| Nil : List T

/- [hashmap::HashMap]
   Source: 'tests/src/hashmap.rs', lines 35:0-35:21 -/
structure HashMap (T : Type) where
  num_entries : Usize
  max_load_factor : (Usize × Usize)
  max_load : Usize
  slots : alloc.vec.Vec (List T)

end hashmap
