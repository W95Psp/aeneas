(** THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS *)
(** [arrays] *)
Require Import Primitives.
Import Primitives.
Require Import Coq.ZArith.ZArith.
Require Import List.
Import ListNotations.
Local Open Scope Primitives_scope.
Module Arrays.

(** [arrays::AB]
    Source: 'tests/src/arrays.rs', lines 6:0-6:11 *)
Inductive AB_t := | AB_A : AB_t | AB_B : AB_t.

(** [arrays::incr]:
    Source: 'tests/src/arrays.rs', lines 11:0-11:24 *)
Definition incr (x : u32) : result u32 :=
  u32_add x 1%u32.

(** [arrays::array_to_shared_slice_]:
    Source: 'tests/src/arrays.rs', lines 19:0-19:53 *)
Definition array_to_shared_slice_
  (T : Type) (s : array T 32%usize) : result (slice T) :=
  array_to_slice T 32%usize s
.

(** [arrays::array_to_mut_slice_]:
    Source: 'tests/src/arrays.rs', lines 24:0-24:58 *)
Definition array_to_mut_slice_
  (T : Type) (s : array T 32%usize) :
  result ((slice T) * (slice T -> result (array T 32%usize)))
  :=
  array_to_slice_mut T 32%usize s
.

(** [arrays::array_len]:
    Source: 'tests/src/arrays.rs', lines 28:0-28:40 *)
Definition array_len (T : Type) (s : array T 32%usize) : result usize :=
  s1 <- array_to_slice T 32%usize s; Ok (slice_len T s1)
.

(** [arrays::shared_array_len]:
    Source: 'tests/src/arrays.rs', lines 32:0-32:48 *)
Definition shared_array_len (T : Type) (s : array T 32%usize) : result usize :=
  s1 <- array_to_slice T 32%usize s; Ok (slice_len T s1)
.

(** [arrays::shared_slice_len]:
    Source: 'tests/src/arrays.rs', lines 36:0-36:44 *)
Definition shared_slice_len (T : Type) (s : slice T) : result usize :=
  Ok (slice_len T s)
.

(** [arrays::index_array_shared]:
    Source: 'tests/src/arrays.rs', lines 40:0-40:57 *)
Definition index_array_shared
  (T : Type) (s : array T 32%usize) (i : usize) : result T :=
  array_index_usize T 32%usize s i
.

(** [arrays::index_array_u32]:
    Source: 'tests/src/arrays.rs', lines 47:0-47:53 *)
Definition index_array_u32 (s : array u32 32%usize) (i : usize) : result u32 :=
  array_index_usize u32 32%usize s i
.

(** [arrays::index_array_copy]:
    Source: 'tests/src/arrays.rs', lines 51:0-51:45 *)
Definition index_array_copy (x : array u32 32%usize) : result u32 :=
  array_index_usize u32 32%usize x 0%usize
.

(** [arrays::index_mut_array]:
    Source: 'tests/src/arrays.rs', lines 55:0-55:62 *)
Definition index_mut_array
  (T : Type) (s : array T 32%usize) (i : usize) :
  result (T * (T -> result (array T 32%usize)))
  :=
  array_index_mut_usize T 32%usize s i
.

(** [arrays::index_slice]:
    Source: 'tests/src/arrays.rs', lines 59:0-59:46 *)
Definition index_slice (T : Type) (s : slice T) (i : usize) : result T :=
  slice_index_usize T s i
.

(** [arrays::index_mut_slice]:
    Source: 'tests/src/arrays.rs', lines 63:0-63:58 *)
Definition index_mut_slice
  (T : Type) (s : slice T) (i : usize) :
  result (T * (T -> result (slice T)))
  :=
  slice_index_mut_usize T s i
.

(** [arrays::slice_subslice_shared_]:
    Source: 'tests/src/arrays.rs', lines 67:0-67:70 *)
Definition slice_subslice_shared_
  (x : slice u32) (y : usize) (z : usize) : result (slice u32) :=
  core_slice_index_Slice_index u32 (core_ops_range_Range usize)
    (core_slice_index_SliceIndexRangeUsizeSliceTInst u32) x
    {| core_ops_range_Range_start := y; core_ops_range_Range_end_ := z |}
.

(** [arrays::slice_subslice_mut_]:
    Source: 'tests/src/arrays.rs', lines 71:0-71:75 *)
Definition slice_subslice_mut_
  (x : slice u32) (y : usize) (z : usize) :
  result ((slice u32) * (slice u32 -> result (slice u32)))
  :=
  p <-
    core_slice_index_Slice_index_mut u32 (core_ops_range_Range usize)
      (core_slice_index_SliceIndexRangeUsizeSliceTInst u32) x
      {| core_ops_range_Range_start := y; core_ops_range_Range_end_ := z |};
  let (s, index_mut_back) := p in
  Ok (s, index_mut_back)
.

(** [arrays::array_to_slice_shared_]:
    Source: 'tests/src/arrays.rs', lines 75:0-75:54 *)
Definition array_to_slice_shared_
  (x : array u32 32%usize) : result (slice u32) :=
  array_to_slice u32 32%usize x
.

(** [arrays::array_to_slice_mut_]:
    Source: 'tests/src/arrays.rs', lines 79:0-79:59 *)
Definition array_to_slice_mut_
  (x : array u32 32%usize) :
  result ((slice u32) * (slice u32 -> result (array u32 32%usize)))
  :=
  array_to_slice_mut u32 32%usize x
.

(** [arrays::array_subslice_shared_]:
    Source: 'tests/src/arrays.rs', lines 83:0-83:74 *)
Definition array_subslice_shared_
  (x : array u32 32%usize) (y : usize) (z : usize) : result (slice u32) :=
  core_array_Array_index u32 (core_ops_range_Range usize) 32%usize
    (core_ops_index_IndexSliceTIInst u32 (core_ops_range_Range usize)
    (core_slice_index_SliceIndexRangeUsizeSliceTInst u32)) x
    {| core_ops_range_Range_start := y; core_ops_range_Range_end_ := z |}
.

(** [arrays::array_subslice_mut_]:
    Source: 'tests/src/arrays.rs', lines 87:0-87:79 *)
Definition array_subslice_mut_
  (x : array u32 32%usize) (y : usize) (z : usize) :
  result ((slice u32) * (slice u32 -> result (array u32 32%usize)))
  :=
  p <-
    core_array_Array_index_mut u32 (core_ops_range_Range usize) 32%usize
      (core_ops_index_IndexMutSliceTIInst u32 (core_ops_range_Range usize)
      (core_slice_index_SliceIndexRangeUsizeSliceTInst u32)) x
      {| core_ops_range_Range_start := y; core_ops_range_Range_end_ := z |};
  let (s, index_mut_back) := p in
  Ok (s, index_mut_back)
.

(** [arrays::index_slice_0]:
    Source: 'tests/src/arrays.rs', lines 91:0-91:38 *)
Definition index_slice_0 (T : Type) (s : slice T) : result T :=
  slice_index_usize T s 0%usize
.

(** [arrays::index_array_0]:
    Source: 'tests/src/arrays.rs', lines 95:0-95:42 *)
Definition index_array_0 (T : Type) (s : array T 32%usize) : result T :=
  array_index_usize T 32%usize s 0%usize
.

(** [arrays::index_index_array]:
    Source: 'tests/src/arrays.rs', lines 106:0-106:71 *)
Definition index_index_array
  (s : array (array u32 32%usize) 32%usize) (i : usize) (j : usize) :
  result u32
  :=
  a <- array_index_usize (array u32 32%usize) 32%usize s i;
  array_index_usize u32 32%usize a j
.

(** [arrays::update_update_array]:
    Source: 'tests/src/arrays.rs', lines 117:0-117:70 *)
Definition update_update_array
  (s : array (array u32 32%usize) 32%usize) (i : usize) (j : usize) :
  result unit
  :=
  p <- array_index_mut_usize (array u32 32%usize) 32%usize s i;
  let (a, index_mut_back) := p in
  p1 <- array_index_mut_usize u32 32%usize a j;
  let (_, index_mut_back1) := p1 in
  a1 <- index_mut_back1 0%u32;
  _ <- index_mut_back a1;
  Ok tt
.

(** [arrays::array_local_deep_copy]:
    Source: 'tests/src/arrays.rs', lines 121:0-121:43 *)
Definition array_local_deep_copy (x : array u32 32%usize) : result unit :=
  Ok tt
.

(** [arrays::take_array]:
    Source: 'tests/src/arrays.rs', lines 125:0-125:30 *)
Definition take_array (a : array u32 2%usize) : result unit :=
  Ok tt.

(** [arrays::take_array_borrow]:
    Source: 'tests/src/arrays.rs', lines 126:0-126:38 *)
Definition take_array_borrow (a : array u32 2%usize) : result unit :=
  Ok tt.

(** [arrays::take_slice]:
    Source: 'tests/src/arrays.rs', lines 127:0-127:28 *)
Definition take_slice (s : slice u32) : result unit :=
  Ok tt.

(** [arrays::take_mut_slice]:
    Source: 'tests/src/arrays.rs', lines 128:0-128:36 *)
Definition take_mut_slice (s : slice u32) : result (slice u32) :=
  Ok s.

(** [arrays::const_array]:
    Source: 'tests/src/arrays.rs', lines 130:0-130:32 *)
Definition const_array : result (array u32 2%usize) :=
  Ok (mk_array u32 2%usize [ 0%u32; 0%u32 ])
.

(** [arrays::const_slice]:
    Source: 'tests/src/arrays.rs', lines 134:0-134:20 *)
Definition const_slice : result unit :=
  _ <- array_to_slice u32 2%usize (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  Ok tt
.

(** [arrays::take_all]:
    Source: 'tests/src/arrays.rs', lines 144:0-144:17 *)
Definition take_all : result unit :=
  _ <- take_array (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  _ <- take_array (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  _ <- take_array_borrow (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  s <- array_to_slice u32 2%usize (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  _ <- take_slice s;
  p <- array_to_slice_mut u32 2%usize (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  let (s1, to_slice_mut_back) := p in
  s2 <- take_mut_slice s1;
  _ <- to_slice_mut_back s2;
  Ok tt
.

(** [arrays::index_array]:
    Source: 'tests/src/arrays.rs', lines 158:0-158:38 *)
Definition index_array (x : array u32 2%usize) : result u32 :=
  array_index_usize u32 2%usize x 0%usize
.

(** [arrays::index_array_borrow]:
    Source: 'tests/src/arrays.rs', lines 161:0-161:46 *)
Definition index_array_borrow (x : array u32 2%usize) : result u32 :=
  array_index_usize u32 2%usize x 0%usize
.

(** [arrays::index_slice_u32_0]:
    Source: 'tests/src/arrays.rs', lines 165:0-165:42 *)
Definition index_slice_u32_0 (x : slice u32) : result u32 :=
  slice_index_usize u32 x 0%usize
.

(** [arrays::index_mut_slice_u32_0]:
    Source: 'tests/src/arrays.rs', lines 169:0-169:50 *)
Definition index_mut_slice_u32_0
  (x : slice u32) : result (u32 * (slice u32)) :=
  i <- slice_index_usize u32 x 0%usize; Ok (i, x)
.

(** [arrays::index_all]:
    Source: 'tests/src/arrays.rs', lines 173:0-173:25 *)
Definition index_all : result u32 :=
  i <- index_array (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  i1 <- index_array (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  i2 <- u32_add i i1;
  i3 <- index_array_borrow (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  i4 <- u32_add i2 i3;
  s <- array_to_slice u32 2%usize (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  i5 <- index_slice_u32_0 s;
  i6 <- u32_add i4 i5;
  p <- array_to_slice_mut u32 2%usize (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  let (s1, to_slice_mut_back) := p in
  p1 <- index_mut_slice_u32_0 s1;
  let (i7, s2) := p1 in
  i8 <- u32_add i6 i7;
  _ <- to_slice_mut_back s2;
  Ok i8
.

(** [arrays::update_array]:
    Source: 'tests/src/arrays.rs', lines 187:0-187:36 *)
Definition update_array (x : array u32 2%usize) : result unit :=
  p <- array_index_mut_usize u32 2%usize x 0%usize;
  let (_, index_mut_back) := p in
  _ <- index_mut_back 1%u32;
  Ok tt
.

(** [arrays::update_array_mut_borrow]:
    Source: 'tests/src/arrays.rs', lines 190:0-190:48 *)
Definition update_array_mut_borrow
  (x : array u32 2%usize) : result (array u32 2%usize) :=
  p <- array_index_mut_usize u32 2%usize x 0%usize;
  let (_, index_mut_back) := p in
  index_mut_back 1%u32
.

(** [arrays::update_mut_slice]:
    Source: 'tests/src/arrays.rs', lines 193:0-193:38 *)
Definition update_mut_slice (x : slice u32) : result (slice u32) :=
  p <- slice_index_mut_usize u32 x 0%usize;
  let (_, index_mut_back) := p in
  index_mut_back 1%u32
.

(** [arrays::update_all]:
    Source: 'tests/src/arrays.rs', lines 197:0-197:19 *)
Definition update_all : result unit :=
  _ <- update_array (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  _ <- update_array (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  x <- update_array_mut_borrow (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  p <- array_to_slice_mut u32 2%usize x;
  let (s, to_slice_mut_back) := p in
  s1 <- update_mut_slice s;
  _ <- to_slice_mut_back s1;
  Ok tt
.

(** [arrays::range_all]:
    Source: 'tests/src/arrays.rs', lines 208:0-208:18 *)
Definition range_all : result unit :=
  p <-
    core_array_Array_index_mut u32 (core_ops_range_Range usize) 4%usize
      (core_ops_index_IndexMutSliceTIInst u32 (core_ops_range_Range usize)
      (core_slice_index_SliceIndexRangeUsizeSliceTInst u32))
      (mk_array u32 4%usize [ 0%u32; 0%u32; 0%u32; 0%u32 ])
      {|
        core_ops_range_Range_start := 1%usize;
        core_ops_range_Range_end_ := 3%usize
      |};
  let (s, index_mut_back) := p in
  s1 <- update_mut_slice s;
  _ <- index_mut_back s1;
  Ok tt
.

(** [arrays::deref_array_borrow]:
    Source: 'tests/src/arrays.rs', lines 217:0-217:46 *)
Definition deref_array_borrow (x : array u32 2%usize) : result u32 :=
  array_index_usize u32 2%usize x 0%usize
.

(** [arrays::deref_array_mut_borrow]:
    Source: 'tests/src/arrays.rs', lines 222:0-222:54 *)
Definition deref_array_mut_borrow
  (x : array u32 2%usize) : result (u32 * (array u32 2%usize)) :=
  i <- array_index_usize u32 2%usize x 0%usize; Ok (i, x)
.

(** [arrays::take_array_t]:
    Source: 'tests/src/arrays.rs', lines 230:0-230:31 *)
Definition take_array_t (a : array AB_t 2%usize) : result unit :=
  Ok tt.

(** [arrays::non_copyable_array]:
    Source: 'tests/src/arrays.rs', lines 232:0-232:27 *)
Definition non_copyable_array : result unit :=
  take_array_t (mk_array AB_t 2%usize [ AB_A; AB_B ])
.

(** [arrays::sum]: loop 0:
    Source: 'tests/src/arrays.rs', lines 245:0-253:1 *)
Fixpoint sum_loop
  (n : nat) (s : slice u32) (sum1 : u32) (i : usize) : result u32 :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    let i1 := slice_len u32 s in
    if i s< i1
    then (
      i2 <- slice_index_usize u32 s i;
      sum3 <- u32_add sum1 i2;
      i3 <- usize_add i 1%usize;
      sum_loop n1 s sum3 i3)
    else Ok sum1
  end
.

(** [arrays::sum]:
    Source: 'tests/src/arrays.rs', lines 245:0-245:28 *)
Definition sum (n : nat) (s : slice u32) : result u32 :=
  sum_loop n s 0%u32 0%usize
.

(** [arrays::sum2]: loop 0:
    Source: 'tests/src/arrays.rs', lines 255:0-264:1 *)
Fixpoint sum2_loop
  (n : nat) (s : slice u32) (s2 : slice u32) (sum1 : u32) (i : usize) :
  result u32
  :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    let i1 := slice_len u32 s in
    if i s< i1
    then (
      i2 <- slice_index_usize u32 s i;
      i3 <- slice_index_usize u32 s2 i;
      i4 <- u32_add i2 i3;
      sum3 <- u32_add sum1 i4;
      i5 <- usize_add i 1%usize;
      sum2_loop n1 s s2 sum3 i5)
    else Ok sum1
  end
.

(** [arrays::sum2]:
    Source: 'tests/src/arrays.rs', lines 255:0-255:41 *)
Definition sum2 (n : nat) (s : slice u32) (s2 : slice u32) : result u32 :=
  let i := slice_len u32 s in
  let i1 := slice_len u32 s2 in
  if negb (i s= i1) then Fail_ Failure else sum2_loop n s s2 0%u32 0%usize
.

(** [arrays::f0]:
    Source: 'tests/src/arrays.rs', lines 266:0-266:11 *)
Definition f0 : result unit :=
  p <- array_to_slice_mut u32 2%usize (mk_array u32 2%usize [ 1%u32; 2%u32 ]);
  let (s, to_slice_mut_back) := p in
  p1 <- slice_index_mut_usize u32 s 0%usize;
  let (_, index_mut_back) := p1 in
  s1 <- index_mut_back 1%u32;
  _ <- to_slice_mut_back s1;
  Ok tt
.

(** [arrays::f1]:
    Source: 'tests/src/arrays.rs', lines 271:0-271:11 *)
Definition f1 : result unit :=
  p <-
    array_index_mut_usize u32 2%usize (mk_array u32 2%usize [ 1%u32; 2%u32 ])
      0%usize;
  let (_, index_mut_back) := p in
  _ <- index_mut_back 1%u32;
  Ok tt
.

(** [arrays::f2]:
    Source: 'tests/src/arrays.rs', lines 276:0-276:17 *)
Definition f2 (i : u32) : result unit :=
  Ok tt.

(** [arrays::f4]:
    Source: 'tests/src/arrays.rs', lines 285:0-285:54 *)
Definition f4
  (x : array u32 32%usize) (y : usize) (z : usize) : result (slice u32) :=
  core_array_Array_index u32 (core_ops_range_Range usize) 32%usize
    (core_ops_index_IndexSliceTIInst u32 (core_ops_range_Range usize)
    (core_slice_index_SliceIndexRangeUsizeSliceTInst u32)) x
    {| core_ops_range_Range_start := y; core_ops_range_Range_end_ := z |}
.

(** [arrays::f3]:
    Source: 'tests/src/arrays.rs', lines 278:0-278:18 *)
Definition f3 (n : nat) : result u32 :=
  i <-
    array_index_usize u32 2%usize (mk_array u32 2%usize [ 1%u32; 2%u32 ])
      0%usize;
  _ <- f2 i;
  let b := array_repeat u32 32%usize 0%u32 in
  s <- array_to_slice u32 2%usize (mk_array u32 2%usize [ 1%u32; 2%u32 ]);
  s1 <- f4 b 16%usize 18%usize;
  sum2 n s s1
.

(** [arrays::SZ]
    Source: 'tests/src/arrays.rs', lines 289:0-289:19 *)
Definition sz_body : result usize := Ok 32%usize.
Definition sz : usize := sz_body%global.

(** [arrays::f5]:
    Source: 'tests/src/arrays.rs', lines 292:0-292:31 *)
Definition f5 (x : array u32 32%usize) : result u32 :=
  array_index_usize u32 32%usize x 0%usize
.

(** [arrays::ite]:
    Source: 'tests/src/arrays.rs', lines 297:0-297:12 *)
Definition ite : result unit :=
  p <- array_to_slice_mut u32 2%usize (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  let (s, to_slice_mut_back) := p in
  p1 <- index_mut_slice_u32_0 s;
  let (_, s1) := p1 in
  p2 <- array_to_slice_mut u32 2%usize (mk_array u32 2%usize [ 0%u32; 0%u32 ]);
  let (s2, to_slice_mut_back1) := p2 in
  p3 <- index_mut_slice_u32_0 s2;
  let (_, s3) := p3 in
  _ <- to_slice_mut_back1 s3;
  _ <- to_slice_mut_back s1;
  Ok tt
.

(** [arrays::zero_slice]: loop 0:
    Source: 'tests/src/arrays.rs', lines 306:0-313:1 *)
Fixpoint zero_slice_loop
  (n : nat) (a : slice u8) (i : usize) (len : usize) : result (slice u8) :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    if i s< len
    then (
      p <- slice_index_mut_usize u8 a i;
      let (_, index_mut_back) := p in
      i1 <- usize_add i 1%usize;
      a1 <- index_mut_back 0%u8;
      zero_slice_loop n1 a1 i1 len)
    else Ok a
  end
.

(** [arrays::zero_slice]:
    Source: 'tests/src/arrays.rs', lines 306:0-306:31 *)
Definition zero_slice (n : nat) (a : slice u8) : result (slice u8) :=
  let len := slice_len u8 a in zero_slice_loop n a 0%usize len
.

(** [arrays::iter_mut_slice]: loop 0:
    Source: 'tests/src/arrays.rs', lines 315:0-321:1 *)
Fixpoint iter_mut_slice_loop
  (n : nat) (len : usize) (i : usize) : result unit :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    if i s< len
    then (i1 <- usize_add i 1%usize; iter_mut_slice_loop n1 len i1)
    else Ok tt
  end
.

(** [arrays::iter_mut_slice]:
    Source: 'tests/src/arrays.rs', lines 315:0-315:35 *)
Definition iter_mut_slice (n : nat) (a : slice u8) : result (slice u8) :=
  let len := slice_len u8 a in _ <- iter_mut_slice_loop n len 0%usize; Ok a
.

(** [arrays::sum_mut_slice]: loop 0:
    Source: 'tests/src/arrays.rs', lines 323:0-331:1 *)
Fixpoint sum_mut_slice_loop
  (n : nat) (a : slice u32) (i : usize) (s : u32) : result u32 :=
  match n with
  | O => Fail_ OutOfFuel
  | S n1 =>
    let i1 := slice_len u32 a in
    if i s< i1
    then (
      i2 <- slice_index_usize u32 a i;
      s1 <- u32_add s i2;
      i3 <- usize_add i 1%usize;
      sum_mut_slice_loop n1 a i3 s1)
    else Ok s
  end
.

(** [arrays::sum_mut_slice]:
    Source: 'tests/src/arrays.rs', lines 323:0-323:42 *)
Definition sum_mut_slice
  (n : nat) (a : slice u32) : result (u32 * (slice u32)) :=
  i <- sum_mut_slice_loop n a 0%usize 0%u32; Ok (i, a)
.

End Arrays.
