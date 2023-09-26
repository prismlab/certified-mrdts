module Set_extended_new

open FStar.List.Tot

let set pos : eqtype = list pos

let mem x s = mem x s

let empty = []

let empty_mem x
  : Lemma (ensures not (mem x empty)) = ()
  
let equal s1 s2 = 
  s1 == s2

let pos_comparator : comparator pos = 
  (fun x y ->
    if x < y then Lt
    else if x > y then Gt
    else Eq)

let e = 1
let e1 = 2 

val test (e e1:pos) : order
let test (e e1:pos) = generic_compare pos e e1 pos_comparator

let le e e1 =
  if test e e1 = Lt then true else false 

let equal_intro s1 s2
  : Lemma (requires (forall x. mem x s1 = mem x s2))
          (ensures (equal s1 s2)) = ()

let equal_elim s1 s2
  : Lemma (requires (equal s1 s2))
          (ensures (s1 == s2)) = ()

type ordering =
  | Less
  | Equal
  | Greater

// Define a generic comparator for a type 'a
type comparator 'a =
  (x: 'a) ->
  (y: 'a) ->
  ordering

// Define a generic compare function that uses the comparator
let generic_compare 'a (comparator: comparator 'a) (x: 'a) (y: 'a): ordering =
  comparator x y

let lt (e e1:int) =
  (comparator int) e e1

// Define a generic comparator for integers
let int_comparator: comparator int =
  fun (x: int) (y: int) ->
    if x < y then Less
    else if x > y then Greater
    else Equal
    
type order = |Lt |Eq |Gt

val comparator (#a:eqtype) (e e1:a) : order 

(*type comparator 'a =
  (x: 'a) ->
  (y: 'a) ->
  order*)

let int_comp (x y:(pos * nat)) : order =
  if fst x < fst y then Lt
    else if fst x > fst y then Gt
    else Eq
  
let int_comparator (x y:(pos * nat)) : comparator (pos * nat) =
  fun (x y:(pos * nat)) ->
    if fst x < fst y then Lt
    else if fst x > fst y then Gt
    else Eq
  

let lt (#a:eqtype) (e e1:a) = comparator a == Lt
