-- THIS FILE WAS AUTOMATICALLY GENERATED BY AENEAS
-- [demo]
import Base
open Primitives

namespace demo

/- [demo::choose]:
   Source: 'tests/src/demo.rs', lines 7:0-7:70 -/
def choose
  (T : Type) (b : Bool) (x : T) (y : T) :
  Result (T × (T → Result (T × T)))
  :=
  if b
  then let back := fun ret => Result.ok (ret, y)
       Result.ok (x, back)
  else let back := fun ret => Result.ok (x, ret)
       Result.ok (y, back)

/- [demo::mul2_add1]:
   Source: 'tests/src/demo.rs', lines 15:0-15:31 -/
def mul2_add1 (x : U32) : Result U32 :=
  do
  let i ← x + x
  i + 1#u32

/- [demo::use_mul2_add1]:
   Source: 'tests/src/demo.rs', lines 19:0-19:43 -/
def use_mul2_add1 (x : U32) (y : U32) : Result U32 :=
  do
  let i ← mul2_add1 x
  i + y

/- [demo::incr]:
   Source: 'tests/src/demo.rs', lines 23:0-23:31 -/
def incr (x : U32) : Result U32 :=
  x + 1#u32

/- [demo::use_incr]:
   Source: 'tests/src/demo.rs', lines 27:0-27:17 -/
def use_incr : Result Unit :=
  do
  let x ← incr 0#u32
  let x1 ← incr x
  let _ ← incr x1
  Result.ok ()

/- [demo::CList]
   Source: 'tests/src/demo.rs', lines 36:0-36:17 -/
inductive CList (T : Type) :=
| CCons : T → CList T → CList T
| CNil : CList T

/- [demo::list_nth]:
   Source: 'tests/src/demo.rs', lines 41:0-41:56 -/
divergent def list_nth (T : Type) (l : CList T) (i : U32) : Result T :=
  match l with
  | CList.CCons x tl =>
    if i = 0#u32
    then Result.ok x
    else do
         let i1 ← i - 1#u32
         list_nth T tl i1
  | CList.CNil => Result.fail .panic

/- [demo::list_nth_mut]:
   Source: 'tests/src/demo.rs', lines 56:0-56:68 -/
divergent def list_nth_mut
  (T : Type) (l : CList T) (i : U32) :
  Result (T × (T → Result (CList T)))
  :=
  match l with
  | CList.CCons x tl =>
    if i = 0#u32
    then
      let back := fun ret => Result.ok (CList.CCons ret tl)
      Result.ok (x, back)
    else
      do
      let i1 ← i - 1#u32
      let (t, list_nth_mut_back) ← list_nth_mut T tl i1
      let back :=
        fun ret =>
          do
          let tl1 ← list_nth_mut_back ret
          Result.ok (CList.CCons x tl1)
      Result.ok (t, back)
  | CList.CNil => Result.fail .panic

/- [demo::list_nth_mut1]: loop 0:
   Source: 'tests/src/demo.rs', lines 71:0-80:1 -/
divergent def list_nth_mut1_loop
  (T : Type) (l : CList T) (i : U32) :
  Result (T × (T → Result (CList T)))
  :=
  match l with
  | CList.CCons x tl =>
    if i = 0#u32
    then
      let back := fun ret => Result.ok (CList.CCons ret tl)
      Result.ok (x, back)
    else
      do
      let i1 ← i - 1#u32
      let (t, back) ← list_nth_mut1_loop T tl i1
      let back1 :=
        fun ret => do
                   let tl1 ← back ret
                   Result.ok (CList.CCons x tl1)
      Result.ok (t, back1)
  | CList.CNil => Result.fail .panic

/- [demo::list_nth_mut1]:
   Source: 'tests/src/demo.rs', lines 71:0-71:77 -/
def list_nth_mut1
  (T : Type) (l : CList T) (i : U32) :
  Result (T × (T → Result (CList T)))
  :=
  list_nth_mut1_loop T l i

/- [demo::i32_id]:
   Source: 'tests/src/demo.rs', lines 82:0-82:28 -/
divergent def i32_id (i : I32) : Result I32 :=
  if i = 0#i32
  then Result.ok 0#i32
  else do
       let i1 ← i - 1#i32
       let i2 ← i32_id i1
       i2 + 1#i32

/- [demo::list_tail]:
   Source: 'tests/src/demo.rs', lines 90:0-90:64 -/
divergent def list_tail
  (T : Type) (l : CList T) :
  Result ((CList T) × (CList T → Result (CList T)))
  :=
  match l with
  | CList.CCons t tl =>
    do
    let (c, list_tail_back) ← list_tail T tl
    let back :=
      fun ret =>
        do
        let tl1 ← list_tail_back ret
        Result.ok (CList.CCons t tl1)
    Result.ok (c, back)
  | CList.CNil => Result.ok (CList.CNil, Result.ok)

/- Trait declaration: [demo::Counter]
   Source: 'tests/src/demo.rs', lines 99:0-99:17 -/
structure Counter (Self : Type) where
  incr : Self → Result (Usize × Self)

/- [demo::{(demo::Counter for usize)}::incr]:
   Source: 'tests/src/demo.rs', lines 104:4-104:31 -/
def CounterUsize.incr (self : Usize) : Result (Usize × Usize) :=
  do
  let self1 ← self + 1#usize
  Result.ok (self, self1)

/- Trait implementation: [demo::{(demo::Counter for usize)}]
   Source: 'tests/src/demo.rs', lines 103:0-103:22 -/
def CounterUsize : Counter Usize := {
  incr := CounterUsize.incr
}

/- [demo::use_counter]:
   Source: 'tests/src/demo.rs', lines 111:0-111:59 -/
def use_counter
  (T : Type) (CounterInst : Counter T) (cnt : T) : Result (Usize × T) :=
  CounterInst.incr cnt

end demo
