(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [hashmap]: function definitions *)
module Hashmap.Funs
open Primitives
include Hashmap.Types
include Hashmap.FunsExternal
include Hashmap.Clauses

#set-options "--z3rlimit 50 --fuel 1 --ifuel 1"

(** [hashmap::hash_key]:
    Source: 'tests/src/hashmap.rs', lines 37:0-37:32 *)
let hash_key (k : usize) : result usize =
  Ok k

(** [hashmap::{hashmap::HashMap<T>}::allocate_slots]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 60:4-66:5 *)
let rec hashMap_allocate_slots_loop
  (t : Type0) (slots : alloc_vec_Vec (list_t t)) (n : usize) :
  Tot (result (alloc_vec_Vec (list_t t)))
  (decreases (hashMap_allocate_slots_loop_decreases t slots n))
  =
  if n > 0
  then
    let* slots1 = alloc_vec_Vec_push (list_t t) slots List_Nil in
    let* n1 = usize_sub n 1 in
    hashMap_allocate_slots_loop t slots1 n1
  else Ok slots

(** [hashmap::{hashmap::HashMap<T>}::allocate_slots]:
    Source: 'tests/src/hashmap.rs', lines 60:4-60:76 *)
let hashMap_allocate_slots
  (t : Type0) (slots : alloc_vec_Vec (list_t t)) (n : usize) :
  result (alloc_vec_Vec (list_t t))
  =
  hashMap_allocate_slots_loop t slots n

(** [hashmap::{hashmap::HashMap<T>}::new_with_capacity]:
    Source: 'tests/src/hashmap.rs', lines 69:4-73:13 *)
let hashMap_new_with_capacity
  (t : Type0) (capacity : usize) (max_load_dividend : usize)
  (max_load_divisor : usize) :
  result (hashMap_t t)
  =
  let* slots = hashMap_allocate_slots t (alloc_vec_Vec_new (list_t t)) capacity
    in
  let* i = usize_mul capacity max_load_dividend in
  let* i1 = usize_div i max_load_divisor in
  Ok
    {
      num_entries = 0;
      max_load_factor = (max_load_dividend, max_load_divisor);
      max_load = i1;
      slots = slots
    }

(** [hashmap::{hashmap::HashMap<T>}::new]:
    Source: 'tests/src/hashmap.rs', lines 85:4-85:24 *)
let hashMap_new (t : Type0) : result (hashMap_t t) =
  hashMap_new_with_capacity t 32 4 5

(** [hashmap::{hashmap::HashMap<T>}::clear]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 90:4-98:5 *)
let rec hashMap_clear_loop
  (t : Type0) (slots : alloc_vec_Vec (list_t t)) (i : usize) :
  Tot (result (alloc_vec_Vec (list_t t)))
  (decreases (hashMap_clear_loop_decreases t slots i))
  =
  let i1 = alloc_vec_Vec_len (list_t t) slots in
  if i < i1
  then
    let* (_, index_mut_back) =
      alloc_vec_Vec_index_mut (list_t t) usize
        (core_slice_index_SliceIndexUsizeSliceTInst (list_t t)) slots i in
    let* i2 = usize_add i 1 in
    let* slots1 = index_mut_back List_Nil in
    hashMap_clear_loop t slots1 i2
  else Ok slots

(** [hashmap::{hashmap::HashMap<T>}::clear]:
    Source: 'tests/src/hashmap.rs', lines 90:4-90:27 *)
let hashMap_clear (t : Type0) (self : hashMap_t t) : result (hashMap_t t) =
  let* hm = hashMap_clear_loop t self.slots 0 in
  Ok { self with num_entries = 0; slots = hm }

(** [hashmap::{hashmap::HashMap<T>}::len]:
    Source: 'tests/src/hashmap.rs', lines 100:4-100:30 *)
let hashMap_len (t : Type0) (self : hashMap_t t) : result usize =
  Ok self.num_entries

(** [hashmap::{hashmap::HashMap<T>}::insert_in_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 107:4-124:5 *)
let rec hashMap_insert_in_list_loop
  (t : Type0) (key : usize) (value : t) (ls : list_t t) :
  Tot (result (bool & (list_t t)))
  (decreases (hashMap_insert_in_list_loop_decreases t key value ls))
  =
  begin match ls with
  | List_Cons ckey cvalue tl ->
    if ckey = key
    then Ok (false, List_Cons ckey value tl)
    else
      let* (b, tl1) = hashMap_insert_in_list_loop t key value tl in
      Ok (b, List_Cons ckey cvalue tl1)
  | List_Nil -> Ok (true, List_Cons key value List_Nil)
  end

(** [hashmap::{hashmap::HashMap<T>}::insert_in_list]:
    Source: 'tests/src/hashmap.rs', lines 107:4-107:71 *)
let hashMap_insert_in_list
  (t : Type0) (key : usize) (value : t) (ls : list_t t) :
  result (bool & (list_t t))
  =
  hashMap_insert_in_list_loop t key value ls

(** [hashmap::{hashmap::HashMap<T>}::insert_no_resize]:
    Source: 'tests/src/hashmap.rs', lines 127:4-127:54 *)
let hashMap_insert_no_resize
  (t : Type0) (self : hashMap_t t) (key : usize) (value : t) :
  result (hashMap_t t)
  =
  let* hash = hash_key key in
  let i = alloc_vec_Vec_len (list_t t) self.slots in
  let* hash_mod = usize_rem hash i in
  let* (l, index_mut_back) =
    alloc_vec_Vec_index_mut (list_t t) usize
      (core_slice_index_SliceIndexUsizeSliceTInst (list_t t)) self.slots
      hash_mod in
  let* (inserted, l1) = hashMap_insert_in_list t key value l in
  if inserted
  then
    let* i1 = usize_add self.num_entries 1 in
    let* v = index_mut_back l1 in
    Ok { self with num_entries = i1; slots = v }
  else let* v = index_mut_back l1 in Ok { self with slots = v }

(** [hashmap::{hashmap::HashMap<T>}::move_elements_from_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 193:4-206:5 *)
let rec hashMap_move_elements_from_list_loop
  (t : Type0) (ntable : hashMap_t t) (ls : list_t t) :
  Tot (result (hashMap_t t))
  (decreases (hashMap_move_elements_from_list_loop_decreases t ntable ls))
  =
  begin match ls with
  | List_Cons k v tl ->
    let* ntable1 = hashMap_insert_no_resize t ntable k v in
    hashMap_move_elements_from_list_loop t ntable1 tl
  | List_Nil -> Ok ntable
  end

(** [hashmap::{hashmap::HashMap<T>}::move_elements_from_list]:
    Source: 'tests/src/hashmap.rs', lines 193:4-193:72 *)
let hashMap_move_elements_from_list
  (t : Type0) (ntable : hashMap_t t) (ls : list_t t) : result (hashMap_t t) =
  hashMap_move_elements_from_list_loop t ntable ls

(** [hashmap::{hashmap::HashMap<T>}::move_elements]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 181:4-190:5 *)
let rec hashMap_move_elements_loop
  (t : Type0) (ntable : hashMap_t t) (slots : alloc_vec_Vec (list_t t))
  (i : usize) :
  Tot (result ((hashMap_t t) & (alloc_vec_Vec (list_t t))))
  (decreases (hashMap_move_elements_loop_decreases t ntable slots i))
  =
  let i1 = alloc_vec_Vec_len (list_t t) slots in
  if i < i1
  then
    let* (l, index_mut_back) =
      alloc_vec_Vec_index_mut (list_t t) usize
        (core_slice_index_SliceIndexUsizeSliceTInst (list_t t)) slots i in
    let (ls, l1) = core_mem_replace (list_t t) l List_Nil in
    let* ntable1 = hashMap_move_elements_from_list t ntable ls in
    let* i2 = usize_add i 1 in
    let* slots1 = index_mut_back l1 in
    hashMap_move_elements_loop t ntable1 slots1 i2
  else Ok (ntable, slots)

(** [hashmap::{hashmap::HashMap<T>}::move_elements]:
    Source: 'tests/src/hashmap.rs', lines 181:4-181:95 *)
let hashMap_move_elements
  (t : Type0) (ntable : hashMap_t t) (slots : alloc_vec_Vec (list_t t))
  (i : usize) :
  result ((hashMap_t t) & (alloc_vec_Vec (list_t t)))
  =
  hashMap_move_elements_loop t ntable slots i

(** [hashmap::{hashmap::HashMap<T>}::try_resize]:
    Source: 'tests/src/hashmap.rs', lines 150:4-150:28 *)
let hashMap_try_resize
  (t : Type0) (self : hashMap_t t) : result (hashMap_t t) =
  let* max_usize = scalar_cast U32 Usize core_u32_max in
  let capacity = alloc_vec_Vec_len (list_t t) self.slots in
  let* n1 = usize_div max_usize 2 in
  let (i, i1) = self.max_load_factor in
  let* i2 = usize_div n1 i in
  if capacity <= i2
  then
    let* i3 = usize_mul capacity 2 in
    let* ntable = hashMap_new_with_capacity t i3 i i1 in
    let* p = hashMap_move_elements t ntable self.slots 0 in
    let (ntable1, _) = p in
    Ok
      { ntable1 with num_entries = self.num_entries; max_load_factor = (i, i1)
      }
  else Ok { self with max_load_factor = (i, i1) }

(** [hashmap::{hashmap::HashMap<T>}::insert]:
    Source: 'tests/src/hashmap.rs', lines 139:4-139:48 *)
let hashMap_insert
  (t : Type0) (self : hashMap_t t) (key : usize) (value : t) :
  result (hashMap_t t)
  =
  let* self1 = hashMap_insert_no_resize t self key value in
  let* i = hashMap_len t self1 in
  if i > self1.max_load then hashMap_try_resize t self1 else Ok self1

(** [hashmap::{hashmap::HashMap<T>}::contains_key_in_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 216:4-229:5 *)
let rec hashMap_contains_key_in_list_loop
  (t : Type0) (key : usize) (ls : list_t t) :
  Tot (result bool)
  (decreases (hashMap_contains_key_in_list_loop_decreases t key ls))
  =
  begin match ls with
  | List_Cons ckey _ tl ->
    if ckey = key then Ok true else hashMap_contains_key_in_list_loop t key tl
  | List_Nil -> Ok false
  end

(** [hashmap::{hashmap::HashMap<T>}::contains_key_in_list]:
    Source: 'tests/src/hashmap.rs', lines 216:4-216:68 *)
let hashMap_contains_key_in_list
  (t : Type0) (key : usize) (ls : list_t t) : result bool =
  hashMap_contains_key_in_list_loop t key ls

(** [hashmap::{hashmap::HashMap<T>}::contains_key]:
    Source: 'tests/src/hashmap.rs', lines 209:4-209:49 *)
let hashMap_contains_key
  (t : Type0) (self : hashMap_t t) (key : usize) : result bool =
  let* hash = hash_key key in
  let i = alloc_vec_Vec_len (list_t t) self.slots in
  let* hash_mod = usize_rem hash i in
  let* l =
    alloc_vec_Vec_index (list_t t) usize
      (core_slice_index_SliceIndexUsizeSliceTInst (list_t t)) self.slots
      hash_mod in
  hashMap_contains_key_in_list t key l

(** [hashmap::{hashmap::HashMap<T>}::get_in_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 234:4-247:5 *)
let rec hashMap_get_in_list_loop
  (t : Type0) (key : usize) (ls : list_t t) :
  Tot (result t) (decreases (hashMap_get_in_list_loop_decreases t key ls))
  =
  begin match ls with
  | List_Cons ckey cvalue tl ->
    if ckey = key then Ok cvalue else hashMap_get_in_list_loop t key tl
  | List_Nil -> Fail Failure
  end

(** [hashmap::{hashmap::HashMap<T>}::get_in_list]:
    Source: 'tests/src/hashmap.rs', lines 234:4-234:70 *)
let hashMap_get_in_list (t : Type0) (key : usize) (ls : list_t t) : result t =
  hashMap_get_in_list_loop t key ls

(** [hashmap::{hashmap::HashMap<T>}::get]:
    Source: 'tests/src/hashmap.rs', lines 249:4-249:55 *)
let hashMap_get (t : Type0) (self : hashMap_t t) (key : usize) : result t =
  let* hash = hash_key key in
  let i = alloc_vec_Vec_len (list_t t) self.slots in
  let* hash_mod = usize_rem hash i in
  let* l =
    alloc_vec_Vec_index (list_t t) usize
      (core_slice_index_SliceIndexUsizeSliceTInst (list_t t)) self.slots
      hash_mod in
  hashMap_get_in_list t key l

(** [hashmap::{hashmap::HashMap<T>}::get_mut_in_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 255:4-264:5 *)
let rec hashMap_get_mut_in_list_loop
  (t : Type0) (ls : list_t t) (key : usize) :
  Tot (result (t & (t -> result (list_t t))))
  (decreases (hashMap_get_mut_in_list_loop_decreases t ls key))
  =
  begin match ls with
  | List_Cons ckey cvalue tl ->
    if ckey = key
    then let back = fun ret -> Ok (List_Cons ckey ret tl) in Ok (cvalue, back)
    else
      let* (x, back) = hashMap_get_mut_in_list_loop t tl key in
      let back1 =
        fun ret -> let* tl1 = back ret in Ok (List_Cons ckey cvalue tl1) in
      Ok (x, back1)
  | List_Nil -> Fail Failure
  end

(** [hashmap::{hashmap::HashMap<T>}::get_mut_in_list]:
    Source: 'tests/src/hashmap.rs', lines 255:4-255:86 *)
let hashMap_get_mut_in_list
  (t : Type0) (ls : list_t t) (key : usize) :
  result (t & (t -> result (list_t t)))
  =
  hashMap_get_mut_in_list_loop t ls key

(** [hashmap::{hashmap::HashMap<T>}::get_mut]:
    Source: 'tests/src/hashmap.rs', lines 267:4-267:67 *)
let hashMap_get_mut
  (t : Type0) (self : hashMap_t t) (key : usize) :
  result (t & (t -> result (hashMap_t t)))
  =
  let* hash = hash_key key in
  let i = alloc_vec_Vec_len (list_t t) self.slots in
  let* hash_mod = usize_rem hash i in
  let* (l, index_mut_back) =
    alloc_vec_Vec_index_mut (list_t t) usize
      (core_slice_index_SliceIndexUsizeSliceTInst (list_t t)) self.slots
      hash_mod in
  let* (x, get_mut_in_list_back) = hashMap_get_mut_in_list t l key in
  let back =
    fun ret ->
      let* l1 = get_mut_in_list_back ret in
      let* v = index_mut_back l1 in
      Ok { self with slots = v } in
  Ok (x, back)

(** [hashmap::{hashmap::HashMap<T>}::remove_from_list]: loop 0:
    Source: 'tests/src/hashmap.rs', lines 275:4-301:5 *)
let rec hashMap_remove_from_list_loop
  (t : Type0) (key : usize) (ls : list_t t) :
  Tot (result ((option t) & (list_t t)))
  (decreases (hashMap_remove_from_list_loop_decreases t key ls))
  =
  begin match ls with
  | List_Cons ckey x tl ->
    if ckey = key
    then
      let (mv_ls, _) =
        core_mem_replace (list_t t) (List_Cons ckey x tl) List_Nil in
      begin match mv_ls with
      | List_Cons _ cvalue tl1 -> Ok (Some cvalue, tl1)
      | List_Nil -> Fail Failure
      end
    else
      let* (o, tl1) = hashMap_remove_from_list_loop t key tl in
      Ok (o, List_Cons ckey x tl1)
  | List_Nil -> Ok (None, List_Nil)
  end

(** [hashmap::{hashmap::HashMap<T>}::remove_from_list]:
    Source: 'tests/src/hashmap.rs', lines 275:4-275:69 *)
let hashMap_remove_from_list
  (t : Type0) (key : usize) (ls : list_t t) :
  result ((option t) & (list_t t))
  =
  hashMap_remove_from_list_loop t key ls

(** [hashmap::{hashmap::HashMap<T>}::remove]:
    Source: 'tests/src/hashmap.rs', lines 304:4-304:52 *)
let hashMap_remove
  (t : Type0) (self : hashMap_t t) (key : usize) :
  result ((option t) & (hashMap_t t))
  =
  let* hash = hash_key key in
  let i = alloc_vec_Vec_len (list_t t) self.slots in
  let* hash_mod = usize_rem hash i in
  let* (l, index_mut_back) =
    alloc_vec_Vec_index_mut (list_t t) usize
      (core_slice_index_SliceIndexUsizeSliceTInst (list_t t)) self.slots
      hash_mod in
  let* (x, l1) = hashMap_remove_from_list t key l in
  begin match x with
  | None -> let* v = index_mut_back l1 in Ok (None, { self with slots = v })
  | Some x1 ->
    let* i1 = usize_sub self.num_entries 1 in
    let* v = index_mut_back l1 in
    Ok (Some x1, { self with num_entries = i1; slots = v })
  end

(** [hashmap::insert_on_disk]:
    Source: 'tests/src/hashmap.rs', lines 335:0-335:43 *)
let insert_on_disk
  (key : usize) (value : u64) (st : state) : result (state & unit) =
  let* (st1, hm) = utils_deserialize st in
  let* hm1 = hashMap_insert u64 hm key value in
  utils_serialize hm1 st1

(** [hashmap::test1]:
    Source: 'tests/src/hashmap.rs', lines 350:0-350:10 *)
let test1 : result unit =
  let* hm = hashMap_new u64 in
  let* hm1 = hashMap_insert u64 hm 0 42 in
  let* hm2 = hashMap_insert u64 hm1 128 18 in
  let* hm3 = hashMap_insert u64 hm2 1024 138 in
  let* hm4 = hashMap_insert u64 hm3 1056 256 in
  let* i = hashMap_get u64 hm4 128 in
  if not (i = 18)
  then Fail Failure
  else
    let* (_, get_mut_back) = hashMap_get_mut u64 hm4 1024 in
    let* hm5 = get_mut_back 56 in
    let* i1 = hashMap_get u64 hm5 1024 in
    if not (i1 = 56)
    then Fail Failure
    else
      let* (x, hm6) = hashMap_remove u64 hm5 1024 in
      begin match x with
      | None -> Fail Failure
      | Some x1 ->
        if not (x1 = 56)
        then Fail Failure
        else
          let* i2 = hashMap_get u64 hm6 0 in
          if not (i2 = 42)
          then Fail Failure
          else
            let* i3 = hashMap_get u64 hm6 128 in
            if not (i3 = 18)
            then Fail Failure
            else
              let* i4 = hashMap_get u64 hm6 1056 in
              if not (i4 = 256) then Fail Failure else Ok ()
      end

