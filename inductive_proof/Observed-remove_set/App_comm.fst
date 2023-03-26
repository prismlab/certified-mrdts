module App_comm

open FStar.Seq
open FStar.Ghost
module L = FStar.List.Tot

#set-options "--query_stats"
// the concrete state type
type concrete_st = list (nat (*unique id*) * nat (*element*))

// init state
let init_st = []

// equivalence between 2 concrete states
let eq (a b:concrete_st) =
  (forall ele. L.mem ele a <==> L.mem ele b)

// few properties of equivalence relation
let symmetric (a b:concrete_st) 
  : Lemma (requires eq a b)
          (ensures eq b a) = ()

let transitive (a b c:concrete_st)
  : Lemma (requires eq a b /\ eq b c)
          (ensures eq a c) = ()

let eq_is_equiv (a b:concrete_st)
  : Lemma (requires a == b)
          (ensures eq a b) = ()

// operation type
type app_op_t:eqtype =
  |Add : nat -> app_op_t
  |Rem : nat -> app_op_t

let get_ele (o:op_t) : nat =
  match snd o with
  |Add e -> e
  |Rem e -> e

val mem_id_s : id:nat 
             -> l:list (nat * nat)
             -> Tot (b:bool{(exists n. L.mem (id,n) l) <==> b=true})
let rec mem_id_s n l =
  match l with
  |[] -> false
  |(id,_)::xs -> (n = id) || mem_id_s n xs

val mem_ele : ele:nat 
            -> l:list (nat * nat)
            -> Tot (b:bool{(exists n. L.mem (n,ele) l) <==> b=true})
let rec mem_ele ele l =
  match l with
  |[] -> false
  |(_,ele1)::xs -> (ele = ele1) || mem_ele ele xs

val filter : f:((nat * nat) -> bool)
           -> l:concrete_st
           -> Tot (l1:concrete_st {(forall e. L.mem e l /\ f e <==> L.mem e l1)})
let rec filter f l = 
  match l with
  |[] -> []
  |hd::tl -> if f hd then hd::(filter f tl) else filter f tl

// apply an operation to a state
let do (s:concrete_st) (o:op_t) 
    : (r:concrete_st{(Add? (snd o) ==> (forall ele. mem_ele ele r <==> (mem_ele ele s \/ ele = get_ele o)) /\
                                      (forall e. L.mem e r <==> (L.mem e s \/ (e = (fst o, get_ele o)))) /\
                                      (forall id. mem_id_s id r <==> (mem_id_s id s \/ id = fst o)) /\
                                      (forall e. L.mem e r /\ snd e <> get_ele o <==> L.mem e s /\ snd e <> get_ele o) /\
                                      r = (fst o, get_ele o)::s) /\
                     (Rem? (snd o) ==> (forall ele. mem_ele ele r <==> (mem_ele ele s /\ ele <> get_ele o)) /\
                                      (forall e. L.mem e r <==> (L.mem e s /\ snd e <> get_ele o)) /\
                                      (forall id. mem_id_s id r ==> mem_id_s id s) /\
                                      not (mem_ele (get_ele o) r))}) =
  match o with
  |(id, Add e) -> (id, e)::s
  |(id, Rem e) -> filter (fun ele -> snd ele <> e) s

let do_prop (s:concrete_st) (o:op_t)
  : Lemma (ensures (Add? (snd o) ==> ((forall ele. mem_ele ele (do s o) <==> (mem_ele ele s \/ ele = get_ele o)) /\
                                     (forall e. L.mem e (do s o) <==> (L.mem e s \/ e = (fst o, get_ele o))) /\
                                     (forall id. mem_id_s id (do s o) <==> (mem_id_s id s \/ id = fst o)) /\
                                     L.mem (fst o, get_ele o) (do s o) /\
                                    (forall e. L.mem e (do s o) /\ snd e <> get_ele o <==> L.mem e s /\ snd e <> get_ele o) /\
                                    (do s o = (fst o, get_ele o)::s ))) /\
                   (Rem? (snd o) ==> ((forall e. L.mem e (do s o) <==> (L.mem e s /\ snd e <> get_ele o)) /\
                                     not (mem_ele (get_ele o) (do s o)) /\
                                    (forall id. mem_id_s id (do s o) ==> mem_id_s id s)))) = ()

let lem_do (a b:concrete_st) (op:op_t)
   : Lemma (requires eq a b)
           (ensures eq (do a op) (do b op)) = ()
           
val exists_op : f:(op_t -> bool)
              -> l:log
              -> Tot (b:bool{(exists e. mem e l /\ f e) <==> b = true}) (decreases length l)
let rec exists_op f l =
  match length l with
  | 0 -> false
  | _ -> if f (head l) then true else exists_op f (tail l)

val forall_op : f:(op_t -> bool)
              -> l:log
              -> Tot (b:bool{(forall e. mem e l ==> f e) <==> b = true}) (decreases length l)
let rec forall_op f l =
  match length l with
  | 0 -> true
  | _ -> f (head l) && forall_op f (tail l)

//conflict resolution
let resolve_conflict (x:op_t) (y:op_t{fst x <> fst y}) : (l:log{(forall e. mem e l <==> (e == x \/ e == y))}) =
  if (get_ele x = get_ele y && Add? (snd x) && Rem? (snd y)) then 
    cons y (cons x empty) else
      cons x (cons y empty)

let resolve_conflict_prop (x y:op_t) 
  : Lemma (requires fst x <> fst y)
          (ensures Seq.length (resolve_conflict x y) = 2 /\
                   (last (resolve_conflict x y) = x <==> (Add? (snd x) /\ Rem? (snd y) /\ get_ele x = get_ele y)) /\
                   (last (resolve_conflict x y) <> x <==> last (resolve_conflict x y) = y) /\
                   (last (resolve_conflict x y) = y <==> ((Add? (snd x) /\ Rem? (snd y) /\ get_ele x <> get_ele y) \/
                                                        (Add? (snd x) /\ Add? (snd y)) \/
                                                        (Rem? (snd x) /\ Rem? (snd y)) \/
                                                        (Rem? (snd x) /\ Add? (snd y)))))
  = ()

// remove ele from l
let rec remove (l:concrete_st) (ele:(nat * nat)) 
  : Tot (res:concrete_st{(forall e. L.mem e res <==> L.mem e l /\ e <> ele) /\ not (L.mem ele res)}) =
  match l with
  |[] -> []
  |x::xs -> if x = ele then remove xs ele else x::remove xs ele

// a - l
let diff_s (a l:concrete_st)
  : Pure (concrete_st) 
    (requires true)
    (ensures (fun d -> (forall e. L.mem e d <==> (L.mem e a /\ not (L.mem e l))) /\
                       (forall ele. (forall e. L.mem e a /\ snd e = ele <==> L.mem e l /\ snd e = ele) ==>
                               not (mem_ele ele d)) /\
                       (forall ele. not (mem_ele ele a) ==> not (mem_ele ele d)) /\
                       (forall e. L.mem e a /\ not (L.mem e l) <==> L.mem e d)))  (decreases a) =
  filter (fun e -> not (L.mem e l)) a

#push-options "--z3rlimit 200"
val concrete_merge1 (l a b:concrete_st)
           : Pure concrete_st
             (requires true)
             (ensures (fun res -> (forall e. L.mem e res <==> (L.mem e l /\ L.mem e a /\ L.mem e b) \/ 
                                                    (L.mem e (diff_s a l)) \/ (L.mem e (diff_s b l))) /\
                              (forall id. mem_id_s id res ==> (mem_id_s id l \/ mem_id_s id a \/ mem_id_s id b))))
                               (decreases %[l;a;b])
let rec concrete_merge1 l a b =
  match l,a,b with
  |[],[],[] -> []
  |x::xs,_,_ -> if (L.mem x a && L.mem x b) then x::(concrete_merge1 xs (remove a x) (remove b x)) 
                 else if (L.mem x a) then (concrete_merge1 xs (remove a x) b)
                   else if (L.mem x b) then (concrete_merge1 xs a (remove b x))
                     else (concrete_merge1 xs a b)
  |[],x::xs,_ -> x::(concrete_merge1 [] xs b)
  |[],[],x::xs -> b
#pop-options

// concrete merge operation
let concrete_merge (l a b:concrete_st)
    : Tot (res:concrete_st {(forall e. L.mem e res <==> (L.mem e l /\ L.mem e a /\ L.mem e b) \/ 
                                                 (L.mem e (diff_s a l)) \/ (L.mem e (diff_s b l))) /\
                            (l = a ==> (forall e. L.mem e res <==> L.mem e b)) /\
                            (l = b ==> (forall e. L.mem e res <==> L.mem e a)) /\
                            (forall b'. eq b b' ==> eq res (concrete_merge1 l a b')) /\
                            (forall a'. eq a a' ==> eq res (concrete_merge1 l a' b))}) =
 concrete_merge1 l a b

//operations x and y are commutative
let commutative (x y:op_t) =
  not (((Add? (snd x) && Rem? (snd y) && get_ele x = get_ele y) ||
        (Add? (snd y) && Rem? (snd x) && get_ele x = get_ele y))) 

let comm_symmetric (x y:op_t) 
  : Lemma (requires commutative x y)
          (ensures commutative y x) = ()

// if x and y are commutative ops, applying them in any order should give equivalent results
let commutative_prop (x y:op_t) 
  : Lemma (requires commutative x y)
          (ensures (forall s. eq (apply_log s (cons x (cons y empty))) (apply_log s (cons y (cons x empty))))) = ()
                   
let lem_trans_merge_s1' (lca s1 s2 s1':concrete_st)
  : Lemma (requires eq s1 s1')
          (ensures eq (concrete_merge lca s1 s2)
                      (concrete_merge lca s1' s2)) = ()
                      
let lem_trans_merge_s2' (lca s1 s2 s2':concrete_st)
  : Lemma (requires eq s2 s2')
          (ensures eq (concrete_merge lca s1 s2)
                      (concrete_merge lca s1 s2')) = ()
                      
let linearizable_s1_0 (lca s1 s2:st)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s1 == ops_of lca /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1))
          (ensures eq (v_of s2) (concrete_merge (v_of lca) (v_of s1) (v_of s2))) = ()
          
let linearizable_s2_0 (lca s1 s2:st)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    Seq.length (ops_of s1) > Seq.length (ops_of lca) /\
                    ops_of s2 == ops_of lca /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1))
          (ensures eq (v_of s1) (concrete_merge (v_of lca) (v_of s1) (v_of s2))) = ()

let trans_op (a b c:concrete_st) (ele:(nat * nat))
  : Lemma (requires (forall e. L.mem e a <==> (L.mem e b \/ e == ele)) /\
                    (forall e. (L.mem e b \/ e == ele) <==> L.mem e c))
          (ensures eq a c) = ()

let trans_op_ele (a b c:concrete_st) (ele:nat)
  : Lemma (requires (forall e. L.mem e a <==> (L.mem e b /\ snd e <> ele)) /\
                    (forall e. (L.mem e b /\ snd e <> ele) <==> L.mem e c))
          (ensures eq a c) = ()

type common_pre_s2_gt0 (lca s1 s2:st) =
  is_prefix (ops_of lca) (ops_of s1) /\
  is_prefix (ops_of lca) (ops_of s2) /\
  Seq.length (ops_of s2) > Seq.length (ops_of lca) /\
  (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
  (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
  (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca))))

type common_pre_s1_gt0 (lca s1 s2:st) =
  is_prefix (ops_of lca) (ops_of s1) /\
  is_prefix (ops_of lca) (ops_of s2) /\
  Seq.length (ops_of s1) > Seq.length (ops_of lca) /\
  (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
  (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
  (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca))))

type common_pre_nc (lca s1 s2:st) =
  is_prefix (ops_of lca) (ops_of s1) /\
  is_prefix (ops_of lca) (ops_of s2) /\
  (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
  (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
  (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca))))

///////////////////////////////////////////

let rec lem_mem_ele_mem_id_single (a:op_t) (b:log)
  : Lemma (requires mem a b)
          (ensures mem_id (fst a) b) 
          (decreases length b) =
 match length b with
 |_ -> if head b = a then () else lem_mem_ele_mem_id_single a (tail b)
 
let lem_lca_eq''_base_pre (lca s1 s2:st) (last1 last2:op_t)
    : Lemma (requires ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                      not (mem_id (fst last1) (ops_of lca)) /\
                      not (mem_id (fst last2) (ops_of lca)) /\
                      length (ops_of lca) > 0)
            (ensures (let l' = inverse_st lca in
                      let s1' = inverse_st s1 in
                      let s2' = inverse_st s2 in
                      not (mem_id (fst last1) (ops_of l')) /\
                      not (mem_id (fst last2) (ops_of l')) /\
                      ops_of s1' = ops_of l' /\ ops_of s2' = ops_of l')) =
  let l' = inverse_st lca in
  let pre, lastl = un_snoc (ops_of lca) in
  lemma_mem_append pre (create 1 lastl);
  assert (mem lastl (ops_of lca)); 
  lem_mem_ele_mem_id_single lastl (ops_of lca);
  assert (mem_id (fst lastl) (ops_of lca)); 
  assert (not (mem_id (fst last1) (ops_of l')) /\
          not (mem_id (fst last2) (ops_of l')) ); ()

#push-options "--z3rlimit 50"
let lem_l2a_l1r_eq''_base_ind (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires length (ops_of lca) > 0 /\
                    ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    Add? (snd last2) /\ //Rem? (snd last1) /\ get_ele last1 = get_ele last2 /\
                    not (mem_id (fst last1) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of lca)) /\

                    (let l' = inverse_st lca in
                     let s1' = inverse_st s1 in
                     let s2' = inverse_st s2 in
                     eq (do (concrete_merge (v_of l') (do (v_of s1') last1) (v_of s2')) last2)
                        (concrete_merge (v_of l') (do (v_of s1') last1) (do (v_of s2') last2))))

          (ensures eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) =
  let pre, lastl = un_snoc (ops_of lca) in
  lemma_mem_append pre (create 1 lastl); 
  assert (mem lastl (ops_of lca)); 
  lem_mem_ele_mem_id_single lastl (ops_of lca);
  assert (mem_id (fst lastl) (ops_of lca)); 
  assert (fst lastl <> fst last1);
  assert (fst lastl <> fst last2);
  ()
#pop-options

let rec lem_l2a_l1r_eq''_base (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    Add? (snd last2) /\ //Rem? (snd last1) /\ get_ele last1 = get_ele last2 /\ 
                    not (mem_id (fst last1) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of lca)))
          (ensures eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) 
          (decreases length (ops_of lca)) = 
  match length (ops_of lca) with
  |0 -> ()
  |_ -> let l' = inverse_st lca in
       let s1' = inverse_st s1 in
       let s2' = inverse_st s2 in 
       lem_lca_eq''_base_pre lca s1 s2 last1 last2;
       lem_l2a_l1r_eq''_base  l' s1' s2' last1 last2;
       lem_l2a_l1r_eq''_base_ind lca s1 s2 last1 last2

let lem_l2a_l1r_eq''_s10_s2_gt0 (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires ops_of s1 = ops_of lca /\
                    length (ops_of s2) > length (ops_of lca) /\
                    Add? (snd last2) /\ //Rem? (snd last1) /\ get_ele last1 = get_ele last2 /\
                    (let s2' = inverse_st s2 in
                    
                     eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2')) last2)
                        (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2))))
         (ensures (eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2)))) = ()
  
let rec lem_l2a_l1r_eq''_s10 (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires ops_of s1 = ops_of lca /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    Add? (snd last2) /\ //Rem? (snd last1) /\ get_ele last1 = get_ele last2 /\
                    not (mem_id (fst last1) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of lca)))
          (ensures eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2)))
          (decreases %[length (ops_of s2)]) =
  if ops_of s2 = ops_of lca then
     lem_l2a_l1r_eq''_base lca s1 s2 last1 last2
  else 
    (assert (length (ops_of s2) > length (ops_of lca)); 
     let s2' = inverse_st s2 in
     lem_l2a_l1r_eq''_s10 lca s1 s2' last1 last2;
     lem_l2a_l1r_eq''_s10_s2_gt0 lca s1 s2 last1 last2)

let lem_l2a_l1r_eq''_s1_gt0 (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires length (ops_of s1) > length (ops_of lca) /\
                    Add? (snd last2) /\ Rem? (snd last1) /\ get_ele last1 = get_ele last2 /\
                    not (mem_id (fst last1) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of lca)) /\
                   
                    (let s1' = inverse_st s1 in
                    eq (do (concrete_merge (v_of lca) (do (v_of s1') last1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (do (v_of s1') last1) (do (v_of s2) last2)))) 
         (ensures eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                     (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = ()

let rec lem_l2a_l1r_eq'' (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires Add? (snd last2) /\ Rem? (snd last1) /\ get_ele last1 = get_ele last2 /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    not (mem_id (fst last1) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of lca)))
          (ensures eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2)))
          (decreases %[length (ops_of s2); length (ops_of s1)]) = 
  if ops_of s1 = ops_of lca && ops_of s2 = ops_of lca then
    lem_l2a_l1r_eq''_base lca s1 s2 last1 last2
  else if ops_of s1 = ops_of lca then
    lem_l2a_l1r_eq''_s10 lca s1 s2 last1 last2
  else (let s1' = inverse_st s1 in
        lem_inverse (ops_of lca) (ops_of s1); 
        lem_l2a_l1r_eq'' lca s1' s2 last1 last2;
        lem_l2a_l1r_eq''_s1_gt0 lca s1 s2 last1 last2)

let lem_l2a_l1r_eq (lca s1 s2:st)
  : Lemma (requires common_pre lca s1 s2 /\ 
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     Add? (snd last2) /\ Rem? (snd last1) /\ get_ele last1 = get_ele last2 /\
                     //fst last1 <> fst last2 /\
                     //last (resolve_conflict last1 last2) = last2 /\
                     is_prefix (ops_of lca) (ops_of (inverse_st s2)) /\
                     is_prefix (ops_of lca) (ops_of (inverse_st s1))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    eq (do (concrete_merge (v_of lca) (v_of s1) (v_of (inverse_st s2))) last2)
                       (concrete_merge (v_of lca) (v_of s1) (v_of s2)))) =
  lem_diff (ops_of s1) (ops_of lca); 
  lem_diff (ops_of s2) (ops_of lca);
  lem_suf_equal2_last (ops_of lca) (ops_of s1); 
  lem_suf_equal2_last (ops_of lca) (ops_of s2); 
  let _, last1 = un_snoc (ops_of s1) in
  let _, last2 = un_snoc (ops_of s2) in
  let s2' = inverse_st s2 in
  let s1' = inverse_st s1 in
  lem_l2a_l1r_eq'' lca s1' s2' last1 last2

///////////////////////////////////////////

#push-options "--z3rlimit 50"
let lem_l1a_l2r_eq''_base_ind (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires length (ops_of lca) > 0 /\
                    ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    Add? (snd last1) /\ Rem? (snd last2) /\ get_ele last1 = get_ele last2 /\
                    not (mem_id (fst last1) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of lca)) /\

                    (let l' = inverse_st lca in
                     let s1' = inverse_st s1 in
                     let s2' = inverse_st s2 in
                     eq (do (concrete_merge (v_of l') (v_of s1') (do (v_of s2') last2)) last1)
                        (concrete_merge (v_of l') (do (v_of s1') last1) (do (v_of s2') last2))))

          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = 
  let pre, lastl = un_snoc (ops_of lca) in
  lemma_mem_append pre (create 1 lastl);
  assert (mem lastl (ops_of lca)); 
  lem_mem_ele_mem_id_single lastl (ops_of lca);
  assert (mem_id (fst lastl) (ops_of lca)); 
  assert (fst lastl <> fst last1);
  assert (fst lastl <> fst last2);
  ()
#pop-options

let rec lem_l1a_l2r_eq''_base (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    Add? (snd last1) /\ Rem? (snd last2) /\ get_ele last1 = get_ele last2 /\ 
                    not (mem_id (fst last1) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of lca)))
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) 
          (decreases length (ops_of lca)) = 
  match length (ops_of lca) with
  |0 -> ()
  |_ -> let l' = inverse_st lca in
       let s1' = inverse_st s1 in
       let s2' = inverse_st s2 in 
       lem_lca_eq''_base_pre lca s1 s2 last1 last2;
       lem_l1a_l2r_eq''_base  l' s1' s2' last1 last2;
       lem_l1a_l2r_eq''_base_ind lca s1 s2 last1 last2

let lem_l1a_l2r_eq''_s20_s1_gt0 (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires ops_of s2 = ops_of lca /\
                    length (ops_of s1) > length (ops_of lca) /\
                    Add? (snd last1) /\ Rem? (snd last2) /\ get_ele last1 = get_ele last2 /\
                    (let s1' = inverse_st s1 in
                    
                     eq (do (concrete_merge (v_of lca) (v_of s1') (do (v_of s2) last2)) last1)
                        (concrete_merge (v_of lca) (do (v_of s1') last1) (do (v_of s2) last2))))
         (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2)))) = ()
                      
let rec lem_l1a_l2r_eq''_s20 (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires ops_of s2 = ops_of lca /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    Add? (snd last1) /\ Rem? (snd last2) /\ get_ele last1 = get_ele last2 /\
                    not (mem_id (fst last1) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of lca)))
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2)))
          (decreases %[length (ops_of s1)]) =
  if ops_of s1 = ops_of lca then
     lem_l1a_l2r_eq''_base lca s1 s2 last1 last2
  else 
    (assert (length (ops_of s1) > length (ops_of lca)); 
     let s1' = inverse_st s1 in
     lem_l1a_l2r_eq''_s20 lca s1' s2 last1 last2;
     lem_l1a_l2r_eq''_s20_s1_gt0 lca s1 s2 last1 last2)

let lem_l1a_l2r_eq''_s2_gt0 (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires length (ops_of s2) > length (ops_of lca) /\
                    Add? (snd last1) /\ Rem? (snd last2) /\ get_ele last1 = get_ele last2 /\
                    not (mem_id (fst last1) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of lca)) /\
                   
                    (let s2' = inverse_st s2 in
                    eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2)))) 
         (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                     (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = ()
                     
let rec lem_l1a_l2r_eq'' (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires Add? (snd last1) /\ Rem? (snd last2) /\ get_ele last1 = get_ele last2 /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    not (mem_id (fst last1) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of lca)))
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2)))
          (decreases %[length (ops_of s1); length (ops_of s2)]) =
  if ops_of s1 = ops_of lca && ops_of s2 = ops_of lca then
    lem_l1a_l2r_eq''_base lca s1 s2 last1 last2
  else if ops_of s2 = ops_of lca then
    lem_l1a_l2r_eq''_s20 lca s1 s2 last1 last2
  else (assert (length (ops_of s2) > length (ops_of lca));
        let s2' = inverse_st s2 in
        lem_l1a_l2r_eq'' lca s1 s2' last1 last2;
        lem_l1a_l2r_eq''_s2_gt0 lca s1 s2 last1 last2)
        
let lem_l1a_l2r_eq (lca s1 s2:st)
  : Lemma (requires common_pre lca s1 s2 /\ 
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     Add? (snd last1) /\ Rem? (snd last2) /\ get_ele last1 = get_ele last2 /\
                     //fst last1 <> fst last2 /\
                     //last (resolve_conflict last1 last2) = last2 /\
                     is_prefix (ops_of lca) (ops_of (inverse_st s2)) /\
                     is_prefix (ops_of lca) (ops_of (inverse_st s1))))
          (ensures (let _, last1 = un_snoc (ops_of s1) in
                    eq (do (concrete_merge (v_of lca) (v_of (inverse_st s1)) (v_of s2)) last1)
                       (concrete_merge (v_of lca) (v_of s1) (v_of s2)))) =
  lem_diff (ops_of s1) (ops_of lca); 
  lem_diff (ops_of s2) (ops_of lca);
  lem_suf_equal2_last (ops_of lca) (ops_of s1); 
  lem_suf_equal2_last (ops_of lca) (ops_of s2); 
  let _, last1 = un_snoc (ops_of s1) in
  let _, last2 = un_snoc (ops_of s2) in
  let s2' = inverse_st s2 in
  let s1' = inverse_st s1 in
  lem_l1a_l2r_eq'' lca s1' s2' last1 last2

///////////////////////////////////////////

let lem_l2r_s10p (lca s1 s2:st)
  : Lemma (requires common_pre_s2_gt0 lca s1 s2 /\ 
                   (let _, last2 = un_snoc (ops_of s2) in
                    Rem? (snd last2) /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                   (let s2' = inverse_st s2 in
                    is_prefix (ops_of lca) (ops_of s2'))))
          (ensures (let s2' = inverse_st s2 in
                    let _, last2 = un_snoc (ops_of s2) in
                    common_pre_nc lca s1 s2' /\
                    not (mem_id (fst last2) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of s2')) /\
                    not (mem_id (fst last2) (ops_of s1)))) =
  let s2' = inverse_st s2 in
  let _, last2 = un_snoc (ops_of s2) in
  assert (is_prefix (ops_of lca) (ops_of s1));
  assert (is_prefix (ops_of lca) (ops_of s2'));
  assert (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) ;
  lastop_diff (ops_of lca) (ops_of s2);
  assert (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2') (ops_of lca)) ==> lt id id1) ;
  inverse_diff_id1 (ops_of lca) (ops_of s1) (ops_of s2);
  assert (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2') (ops_of lca))));
  assert (common_pre_nc lca s1 s2'); 
  lem_id_s2' (ops_of lca) (ops_of s1) (ops_of s2);
  assert (not (mem_id (fst last2) (ops_of lca)) /\
          not (mem_id (fst last2) (ops_of s2')) /\
          not (mem_id (fst last2) (ops_of s1))); 
  ()

let lem_l2r_s10_base (lca s1 s2:st) (last2:op_t)
  : Lemma (requires common_pre_nc lca s1 s2 /\ 
                    ops_of s1 = ops_of lca /\
                    Rem? (snd last2) /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s2 = ops_of lca)
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2))) = ()

let lem_l2r_s10_ind (lca s1 s2:st) (last2:op_t)
  : Lemma (requires common_pre_s2_gt0 lca s1 s2 /\ 
                    ops_of s1 = ops_of lca /\
                    Rem? (snd last2) /\
                    not (mem_id (fst last2) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of s1)) /\
                    not (mem_id (fst last2) (ops_of s2)) /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                    is_prefix (ops_of lca) (ops_of s2) /\

                    (let s2' = inverse_st s2 in
                    common_pre_nc lca s1 s2' /\ 
                    not (mem_id (fst last2) (ops_of s2')) /\
                    is_prefix (ops_of lca) (ops_of s2') /\
                    eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2))))
                   
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2))) = () 

let common_pre1_pre2 (lca s1 s2:st)
  : Lemma (requires common_pre_nc lca s1 s2 /\
                    length (ops_of s2) > length (ops_of lca))
          (ensures common_pre_s2_gt0 lca s1 s2) = ()
  
let lem_common_pre1_s2' (lca s1 s2:st) (last2:op_t)
  : Lemma (requires common_pre_s2_gt0 lca s1 s2 /\
                    not (mem_id (fst last2) (ops_of s2)) /\
                    not (mem_id (fst last2) (ops_of lca)) /\
                    not (mem_id (fst last2) (ops_of s1)) /\
                   ops_of s1 = ops_of lca /\
                   not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                   is_prefix (ops_of lca) (ops_of s2))
          (ensures (let s2' = inverse_st s2 in
                   common_pre_nc lca s1 s2' /\ 
                   not (mem_id (fst last2) (ops_of s2')) /\
                   is_prefix (ops_of lca) (ops_of s2'))) =
  let s2' = inverse_st s2 in
  assert (is_prefix (ops_of lca) (ops_of s1));
  lem_inverse (ops_of lca) (ops_of s2);
  assert (is_prefix (ops_of lca) (ops_of s2'));
  inverse_diff_id1 (ops_of lca) (ops_of s1) (ops_of s2);
  assert (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2') (ops_of lca))));
  assert (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1);
  lastop_diff (ops_of lca) (ops_of s2);
  assert (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2') (ops_of lca)) ==> lt id id1);
  assert (not (mem_id (fst last2) (ops_of s2'))); 
  ()
  
let rec lem_l2r_s10 (lca s1 s2:st) (last2:op_t)
 : Lemma (requires common_pre_nc lca s1 s2 /\ 
                   ops_of s1 = ops_of lca /\
                   Rem? (snd last2) /\
                   not (mem_id (fst last2) (ops_of lca)) /\
                   not (mem_id (fst last2) (ops_of s1)) /\
                   not (mem_id (fst last2) (ops_of s2)) /\
                   not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                   is_prefix (ops_of lca) (ops_of s2))
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)))
         (decreases %[length (ops_of s2)]) =
   if ops_of s2 = ops_of lca
     then lem_l2r_s10_base lca s1 s2 last2
   else 
     (assert (length (ops_of s2) > length (ops_of lca));
      let s2' = inverse_st s2 in
      common_pre1_pre2 lca s1 s2;
      lem_common_pre1_s2' lca s1 s2 last2;
      lem_l2r_s10 lca s1 s2' last2;
      lem_l2r_s10_ind lca s1 s2 last2)  

let rec lem_not_id (l:log) (op:op_t)
  : Lemma (requires distinct_ops l /\ 
                    not (mem_id (fst op) l))
          (ensures not (mem op l)) (decreases length l) = 
  match length l with
  |0 -> ()
  |_ -> let hd = head l in
       let tl = tail l in
       assert (l = cons hd tl);
       distinct_invert_append (create 1 hd) tl; 
       lem_not_id (tail l) op
  
let rec lem_count_id_ele (l:log) (op:op_t)
  : Lemma (requires count_id (fst op) l = 1 /\ mem op l /\ distinct_ops l)
          (ensures count op l = 1) (decreases length l) =
  match length l with
  |1 -> ()
  |_ -> if (fst (head l) = fst op) 
         then (assert (not (mem_id (fst op) (tail l))); 
               assert (l = cons (head l) (tail l));
               distinct_invert_append (create 1 (head l)) (tail l); 
               lem_not_id (tail l) op)
          else (lemma_tl (head l) (tail l);
                lemma_append_count_id (create 1 (head l)) (tail l);
                distinct_invert_append (create 1 (head l)) (tail l);
                lem_count_id_ele (tail l) op)

let lem_lastop_suf_0_help (l2:log) (op:op_t)
  : Lemma (requires last (cons op l2) = op /\
                    count op (cons op l2) = 1)
          (ensures not (mem op l2) /\ length l2 = 0) =
  lemma_mem_append (create 1 op) l2;
  lemma_append_count (create 1 op) l2
  
let lem_lastop_suf_0 (l l1 l2:log) (op:op_t)
  : Lemma (requires distinct_ops l /\ mem op l /\
                    l = snoc l1 op ++ l2 /\
                    (lemma_mem_append (snoc l1 op) l2;
                    last l = op))
          (ensures length l2 = 0) =
  lemma_mem_append (snoc l1 op) l2;
  lemma_append_count (snoc l1 op) l2;
  mem_ele_id op l;
  count_1 l;
  lem_count_id_ele l op;
  assert (count op l = 1); 
  append_assoc l1 (create 1 op) l2;
  assert (l = l1 ++ cons op l2);

  lemma_mem_append l1 (cons op l2);
  lemma_append_count l1 (cons op l2);
  lemma_mem_append (create 1 op) l2;
  lemma_append_count (create 1 op) l2;
  assert (mem op (cons op l2)); 
  assert (count op (cons op l2) = 1); 
  assert (last l = last (cons op l2));
  lem_lastop_suf_0_help l2 op
  
let not_add_eq (lca s1 s2:st)
  : Lemma (requires Seq.length (ops_of s1) > Seq.length (ops_of lca) /\
                    common_pre_s2_gt0 lca s1 s2 /\
                    (let _, last2 = un_snoc (ops_of s2) in
                     let _, last1 = un_snoc (ops_of s1) in
                     Rem? (snd last2) /\
                     not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                     (let s2' = inverse_st s2 in
                     is_prefix (ops_of lca) (ops_of s2')))) 
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let _, last1 = un_snoc (ops_of s1) in
                    ~ (Add? (snd last1) /\ get_ele last1 = get_ele last2))) = 
  let _, last2 = un_snoc (ops_of s2) in
  let _, last1 = un_snoc (ops_of s1) in
  lastop_neq (ops_of lca) (ops_of s1) (ops_of s2); 
  assert (fst last1 <> fst last2);

  let s1' = inverse_st s1 in
  lemma_mem_snoc (ops_of s1') last1;
  assert (mem last1 (ops_of s1)); 
  lem_last (ops_of s1);
  assert (last (ops_of s1) = last1);
  lem_diff (ops_of s1) (ops_of lca);
  assert (last (diff (ops_of s1) (ops_of lca)) = last1);
  assert (mem last1 (diff (ops_of s1) (ops_of lca)));
  let pre, suf = pre_suf (diff (ops_of s1) (ops_of lca)) last1 in
  lem_lastop_suf_0 (diff (ops_of s1) (ops_of lca)) pre suf last1;
  assert (length suf = 0);
  lemma_empty suf; 
  comm_empty_log last1 suf; 
  assert (commutative_seq last1 suf);

  assert ((Add? (snd last1) /\ get_ele last1 = get_ele last2) ==> not (commutative last1 last2));
  resolve_conflict_prop last2 last1;
  assert ((Add? (snd last1) /\ get_ele last1 = get_ele last2) ==> 
                last (resolve_conflict last2 last1) = last1);
  assert ((Add? (snd last1) /\ get_ele last1 = get_ele last2) ==> 
                not (commutative last2 last1) /\
                last (resolve_conflict last2 last1) = last1 /\
                commutative_seq last1 suf);
  assert ((Add? (snd last1) /\ get_ele last1 = get_ele last2) ==> exists_triple last2 (diff (ops_of s1) (ops_of lca)));
  assert (~ (Add? (snd last1) /\ get_ele last1 = get_ele last2)); ()

let lem_l2r_l1r_eq (lca s1 s2:st)
  : Lemma (requires Seq.length (ops_of s1) > Seq.length (ops_of lca) /\
                    common_pre_s2_gt0 lca s1 s2 /\
                    (let _, last2 = un_snoc (ops_of s2) in
                     let _, last1 = un_snoc (ops_of s1) in
                     Rem? (snd last2) /\ Rem? (snd last1) && get_ele last1 = get_ele last2 /\
                     not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                     (let s2' = inverse_st s2 in
                     is_prefix (ops_of lca) (ops_of s2'))))              
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let s2' = inverse_st s2 in
                    eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
                       (concrete_merge (v_of lca) (v_of s1) (v_of s2)))) =
  let pre2, last2 = un_snoc (ops_of s2) in
  let pre1, last1 = un_snoc (ops_of s1) in
  let s2' = inverse_st s2 in
  let s1' = inverse_st s1 in
  lem_last (ops_of s2);
  do_prop (v_of s2') last2;
  assert (forall e. (L.mem e (v_of s2') /\ snd e <> get_ele last2) <==> L.mem e (v_of s2));
  assert (forall e. L.mem e (diff_s (v_of s2) (v_of lca)) <==>
               L.mem e (diff_s (v_of s2') (v_of lca)) /\ snd e <> get_ele last2);
  lem_last (ops_of s1);
  do_prop (v_of s1') last1;
  assert (not (mem_ele (get_ele last1) (v_of s1)));
  assert (not (mem_ele (get_ele last2) (diff_s (v_of s1) (v_of lca)))); 
  assert (forall e. ((L.mem e (v_of lca) /\ L.mem e (v_of s1) /\ L.mem e (v_of s2')) /\ snd e <> get_ele last2) <==>
               (L.mem e (v_of lca) /\ L.mem e (v_of s1) /\ L.mem e (v_of s2)));   
  assert (forall e. L.mem e (concrete_merge (v_of lca) (v_of s1) (v_of s2)) <==>
               (L.mem e (concrete_merge (v_of lca) (v_of s1) (v_of s2')) /\ snd e <> get_ele last2));

  do_prop (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2;
  assert (forall e. (L.mem e (concrete_merge (v_of lca) (v_of s1) (v_of s2')) /\ snd e <> get_ele last2) <==>
                L.mem e (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)); 

  trans_op_ele (concrete_merge (v_of lca) (v_of s1) (v_of s2)) 
               (concrete_merge (v_of lca) (v_of s1) (v_of s2'))
               (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
               (get_ele last2);
  assert (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
             (concrete_merge (v_of lca) (v_of s1) (v_of s2))); ()

let lem_l2r_neq_p1 (lca s1 s2:st)
 : Lemma (requires common_pre_s2_gt0 lca s1 s2 /\ 
                   length (ops_of s1) > length (ops_of lca) /\
                   (let _, last2 = un_snoc (ops_of s2) in
                    let _, last1 = un_snoc (ops_of s1) in
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                   (let s2' = inverse_st s2 in
                    is_prefix (ops_of lca) (ops_of s2'))))
         (ensures (let s1' = inverse_st s1 in
                   common_pre_s2_gt0 lca s1' s2)) =
 let s1' = inverse_st s1 in
 let s2' = inverse_st s2 in
 lem_inverse (ops_of lca) (ops_of s1);
 assert (is_prefix (ops_of lca) (ops_of s1')); 
 inverse_diff_id (ops_of lca) (ops_of s1) (ops_of s2);
 assert (forall id. mem_id id (diff (ops_of s1') (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca))));
 lastop_diff (ops_of lca) (ops_of s1);
 assert (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1') (ops_of lca)) ==> lt id id1); 
 assert (common_pre_s2_gt0 lca s1' s2);
 ()

let lem_l2r_neq_p2' (l:log) (last2:op_t)
  : Lemma (requires distinct_ops l /\ length l > 0 /\
                    Rem? (snd last2) /\
                   (let l', last1 = un_snoc l in
                    get_ele last1 <> get_ele last2))
          (ensures (let l', last1 = un_snoc l in 
                    (exists_triple last2 l' ==> exists_triple last2 l) /\
                    (not (exists_triple last2 l) ==> not (exists_triple last2 l')))) = () //check

let lem_l2r_neq_p2 (lca s1 s2:st)
 : Lemma (requires common_pre_s2_gt0 lca s1 s2 /\ 
                   length (ops_of s1) > length (ops_of lca) /\
                   (let _, last2 = un_snoc (ops_of s2) in
                    let _, last1 = un_snoc (ops_of s1) in
                    Rem? (snd last2) /\ get_ele last1 <> get_ele last2 /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                   (let s2' = inverse_st s2 in
                    is_prefix (ops_of lca) (ops_of s2'))))
         (ensures (let s1' = inverse_st s1 in
                   let s2' = inverse_st s2 in
                   let _, last2 = un_snoc (ops_of s2) in
                   (lem_l2r_neq_p1 lca s1 s2;
                    (not (exists_triple last2 (diff (ops_of s1') (ops_of lca))))))) = 
 lem_l2r_neq_p1 lca s1 s2;
 let s1' = inverse_st s1 in
 let _, last2 = un_snoc (ops_of s2) in
 let pre1, last1 = un_snoc (ops_of s1) in
 let pre1d, last1d = un_snoc (diff (ops_of s1) (ops_of lca)) in
 lem_diff (ops_of s1) (ops_of lca);
 assert (last1 = last1d);
 assert (get_ele last1d <> get_ele last2);
 assert ((diff (ops_of s1') (ops_of lca)) = pre1d);
 lem_l2r_neq_p2' (diff (ops_of s1) (ops_of lca)) last2

let lem_not_ele_diff1 (lca s1 s2 m:concrete_st) (ele:nat)
  : Lemma (requires not (mem_ele ele m) /\
                    eq m (concrete_merge lca s1 s2) /\
                    not (mem_ele ele (diff_s s2 lca)) /\
                    (forall e. L.mem e lca /\ L.mem e s1 /\ L.mem e s2 ==> snd e <> ele))
          (ensures not (mem_ele ele (diff_s s1 lca))) = ()

let lem_not_ele_diff (s1' s1 lca:concrete_st) (op:op_t) (ele:nat)
  : Lemma (requires s1 == do s1' op /\ get_ele op <> ele /\
                    not (mem_ele ele (diff_s s1' lca)))
          (ensures not (mem_ele ele (diff_s s1 lca))) = ()

#push-options "--z3rlimit 50"
let lem_l2r_ind (lca s1 s2:st)
  : Lemma (requires (Seq.length (ops_of s1) > Seq.length (ops_of lca) /\
                    (let s1' = inverse_st s1 in
                    common_pre_s2_gt0 lca s1 s2 /\
                    (let s2' = inverse_st s2 in
                    (let _, last2 = un_snoc (ops_of s2) in
                    let _, last1 = un_snoc (ops_of s1) in
                    Rem? (snd last2) /\ get_ele last2 <> get_ele last1 /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2') /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                    eq (do (concrete_merge (v_of lca) (v_of s1') (v_of s2')) last2)
                       (concrete_merge (v_of lca) (v_of s1') (v_of s2)))))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let s2' = inverse_st s2 in
                    eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
                       (concrete_merge (v_of lca) (v_of s1) (v_of s2)))) =
  let _, last2 = un_snoc (ops_of s2) in 
  let s2' = inverse_st s2 in 
  lem_last (ops_of s2); 
  do_prop (v_of s2') last2; 
  assert (not (mem_ele (get_ele last2) (v_of s2)));
  assert (not (mem_ele (get_ele last2) (diff_s (v_of s2) (v_of lca))));
  let _, last1 = un_snoc (ops_of s1) in
  let s1' = inverse_st s1 in
  lem_last (ops_of s1);
  do_prop (concrete_merge (v_of lca) (v_of s1') (v_of s2')) last2;
  assert (not (mem_ele (get_ele last2) (do (concrete_merge (v_of lca) (v_of s1') (v_of s2')) last2))); 
  assert (forall e. L.mem e (v_of lca) /\ L.mem e (v_of s1') /\ L.mem e (v_of s2) ==> snd e <> get_ele last2); 
  lem_not_ele_diff1 (v_of lca) (v_of s1') (v_of s2) (do (concrete_merge (v_of lca) (v_of s1') (v_of s2')) last2) (get_ele last2);
  assert (not (mem_ele (get_ele last2) (diff_s (v_of s1') (v_of lca)))); 
  lem_not_ele_diff (v_of s1') (v_of s1) (v_of lca) last1 (get_ele last2);
  assert (not (mem_ele (get_ele last2) (diff_s (v_of s1) (v_of lca))));
  ()
#pop-options

let rec lem_l2r' (lca s1 s2:st)
 : Lemma (requires common_pre_s2_gt0 lca s1 s2 /\ 
                   (let _, last2 = un_snoc (ops_of s2) in
                    Rem? (snd last2) /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                   (let s2' = inverse_st s2 in
                    is_prefix (ops_of lca) (ops_of s2'))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let s2' = inverse_st s2 in
                    eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
                       (concrete_merge (v_of lca) (v_of s1) (v_of s2))))
         (decreases %[length (ops_of s1)]) =
   let _, last2 = un_snoc (ops_of s2) in
   if ops_of s1 = ops_of lca then
     (let s2' = inverse_st s2 in
      lem_l2r_s10p lca s1 s2;
      lem_l2r_s10 lca s1 s2' last2) 
   else 
     (assert ((length (ops_of s1) > length (ops_of lca)));
      let _, last1 = un_snoc (ops_of s1) in
      not_add_eq lca s1 s2;
      assert (~ (Add? (snd last1) /\ get_ele last1 = get_ele last2));
      let s1' = inverse_st s1 in
      if Rem? (snd last1) && get_ele last1 = get_ele last2 then
        lem_l2r_l1r_eq lca s1 s2
      else if get_ele last1 <> get_ele last2 then
        (lem_l2r_neq_p1 lca s1 s2;
         lem_l2r_neq_p2 lca s1 s2;
         lem_l2r' lca s1' s2;
         lem_l2r_ind lca s1 s2)
      else ())
      
let lem_l2r (lca s1 s2:st)
 : Lemma (requires common_pre lca s1 s2 /\ 
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     fst last1 <> fst last2 /\
                     Rem? (snd last2) /\
                     not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                     not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                     last (resolve_conflict last1 last2) = last2 /\
                     is_prefix (ops_of lca) (ops_of (inverse_st s2))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    eq (do (concrete_merge (v_of lca) (v_of s1) (v_of (inverse_st s2))) last2)
                       (concrete_merge (v_of lca) (v_of s1) (v_of s2)))) =
 lem_l2r' lca s1 s2

///////////////////////////////////////////
   
let lem_l2a''_ind (lca s1 s2:st) (last2:op_t)
  : Lemma (requires common_pre_nc lca s1 s2 /\
                    Add? (snd last2) /\
                    length (ops_of s2) > length (ops_of lca) /\
                    
                    (let s2' = inverse_st s2 in
                    common_pre_nc lca s1 s2' /\
                    eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2))))
                                       
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2))) = () 

let pre1_pre2_s2 (lca s1 s2:st)
    : Lemma (requires common_pre_s2_gt0 lca s1 s2)
            (ensures common_pre_nc lca s1 (inverse_st s2)) = 
  lem_inverse (ops_of lca) (ops_of s2);
  lastop_diff (ops_of lca) (ops_of s2);
  inverse_diff_id1 (ops_of lca) (ops_of s1) (ops_of s2)

let pre2_pre1_s2 (lca s1 s2:st)
  : Lemma (requires common_pre_nc lca s1 s2 /\
                    length (ops_of s2) > length (ops_of lca))
          (ensures common_pre_s2_gt0 lca s1 s2) = ()

let lem_l2a''_s20_base (lca s1 s2:st) (last2:op_t)
  : Lemma (requires common_pre_nc lca s1 s2 /\
                    ops_of s2 = ops_of lca /\ ops_of s1 = ops_of lca /\
                    Add? (snd last2) /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))))
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2))) = ()

let lem_l2a''_s20_ind_l1r_neq (lca s1 s2:st) (last2:op_t)
  : Lemma (requires common_pre_nc lca s1 s2 /\
                    ops_of s2 = ops_of lca /\ 
                    length (ops_of s1) > length (ops_of lca) /\
                    (let _, last1 = un_snoc (ops_of s1) in
                    Add? (snd last2) /\ Rem? (snd last1) /\ get_ele last1 <> get_ele last2 /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca)))) /\

                    (let s1' = inverse_st s1 in
                     common_pre_nc lca s1' s2 /\
                     not (exists_triple last2 (diff (ops_of s1') (ops_of lca))) /\                  
                     eq (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1') (do (v_of s2) last2))))
                     
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2))) =  ()

let lem_l2a''_s20_ind_l1r_eq (lca s1 s2:st) (last2:op_t)
  : Lemma (requires common_pre_nc lca s1 s2 /\
                    ops_of s2 = ops_of lca /\ 
                    length (ops_of s1) > length (ops_of lca) /\
                    (let _, last1 = un_snoc (ops_of s1) in
                    Add? (snd last2) /\ Rem? (snd last1) /\ get_ele last1 = get_ele last2 /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca)))) /\
                    not (mem_id (fst last2) (ops_of lca)) /\

                    (let s1' = inverse_st s1 in
                     common_pre_nc lca s1' s2 /\
                     not (exists_triple last2 (diff (ops_of s1') (ops_of lca))) /\                  
                     eq (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1') (do (v_of s2) last2))))
                     
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2))) = 
  let _, last1 = un_snoc (ops_of s1) in
  lem_inverse (ops_of lca) (ops_of s1);
  lem_diff (ops_of s1) (ops_of lca); 
  lem_suf_equal2_last (ops_of lca) (ops_of s1); 
  lem_l2a_l1r_eq'' lca (inverse_st s1) s2 last1 last2
                      
let lem_l2a''_s20_ind_l1a (lca s1 s2:st) (last2:op_t)
  : Lemma (requires common_pre_nc lca s1 s2 /\
                    ops_of s2 = ops_of lca /\ 
                    length (ops_of s1) > length (ops_of lca) /\
                    (let _, last1 = un_snoc (ops_of s1) in
                    Add? (snd last2) /\ Add? (snd last1) /\ 
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca)))) /\

                    (let s1' = inverse_st s1 in
                     common_pre_nc lca s1' s2 /\
                     not (exists_triple last2 (diff (ops_of s1') (ops_of lca))) /\                  
                     eq (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1') (do (v_of s2) last2))))
                     
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2))) = ()

let lem_l2a''_s20_ind (lca s1 s2:st) (last2:op_t)
  : Lemma (requires common_pre_nc lca s1 s2 /\
                    ops_of s2 = ops_of lca /\ 
                    length (ops_of s1) > length (ops_of lca) /\
                    Add? (snd last2) /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                    not (mem_id (fst last2) (ops_of lca)) /\
                    
                    (let s1' = inverse_st s1 in
                     common_pre_nc lca s1' s2 /\
                     not (exists_triple last2 (diff (ops_of s1') (ops_of lca))) /\                  
                     eq (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1') (do (v_of s2) last2))))
                     
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2))) = 
  let _, last1 = un_snoc (ops_of s1) in
  if Rem? (snd last1) && get_ele last1 <> get_ele last2 then
    lem_l2a''_s20_ind_l1r_neq lca s1 s2 last2
  else if Add? (snd last1) then
    lem_l2a''_s20_ind_l1a lca s1 s2 last2 
  else lem_l2a''_s20_ind_l1r_eq lca s1 s2 last2
 
let pre1_pre2_s1 (lca s1 s2:st)
    : Lemma (requires common_pre_s1_gt0 lca s1 s2)
            (ensures common_pre_nc lca (inverse_st s1) s2) = 
  lem_inverse (ops_of lca) (ops_of s1);
  lastop_diff (ops_of lca) (ops_of s1);
  inverse_diff_id (ops_of lca) (ops_of s1) (ops_of s2)

let pre2_pre1_s1 (lca s1 s2:st)
  : Lemma (requires common_pre_nc lca s1 s2 /\
                    length (ops_of s1) > length (ops_of lca))
          (ensures common_pre_s1_gt0 lca s1 s2) = ()

let diff_inv (a l:log)
  : Lemma (requires length a > 0 /\ distinct_ops a /\ distinct_ops l /\
                    is_prefix l a /\ is_prefix l (fst (un_snoc a)))
          (ensures (let a',_ = un_snoc a in
                        (forall e. mem e (diff a' l) ==> mem e (diff a l)))) = 
  let a', last1 = un_snoc a in
  lemma_mem_snoc a' last1;
  lemma_mem_snoc (diff a' l) last1

let lem_not_exists_add (lastop:op_t) (l:log)
  : Lemma (requires Add? (snd lastop) /\ length l > 0)
          (ensures not (exists_triple lastop l) ==>
                       (let pre1, _ = un_snoc l in
                        not (exists_triple lastop pre1)))
  = ()
  
let rec lem_l2a''_s20 (lca s1 s2:st) (last2:op_t)
  : Lemma (requires common_pre_nc lca s1 s2 /\
                    ops_of s2 = ops_of lca /\
                    Add? (snd last2) /\
                    not (mem_id (fst last2) (ops_of lca)) /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))))
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)))
          (decreases %[length (ops_of s1)]) = 
  if ops_of s1 = ops_of lca then 
    lem_l2a''_s20_base lca s1 s2 last2
  else 
    (assert (length (ops_of s1) > length (ops_of lca));
     let s1' = inverse_st s1 in
     pre2_pre1_s1 lca s1 s2;
     pre1_pre2_s1 lca s1 s2;
     assert (common_pre_nc lca s1' s2);
     let pre1, last1 = un_snoc (ops_of s1) in
     let pre1d, last1d = un_snoc (diff (ops_of s1) (ops_of lca)) in
     lem_diff (ops_of s1) (ops_of lca);
     assert (last1 = last1d);
     assert ((diff (ops_of s1') (ops_of lca)) = pre1d);
     lem_not_exists_add last2 (diff (ops_of s1) (ops_of lca));
     assert (not (exists_triple last2 (diff (ops_of s1') (ops_of lca))));
     lem_inverse (ops_of lca) (ops_of s1);
     lem_l2a''_s20 lca s1' s2 last2;
     lem_l2a''_s20_ind lca s1 s2 last2)

let rec lem_l2a'' (lca s1 s2:st) (last2:op_t)
  : Lemma (requires common_pre_nc lca s1 s2 /\
                    Add? (snd last2) /\
                    not (mem_id (fst last2) (ops_of lca)))
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2))) 
          (decreases %[length (ops_of s2)]) =
  if ops_of s2 = ops_of lca then
    lem_l2a''_s20 lca s1 s2 last2
  else 
    (assert (length (ops_of s2) > length (ops_of lca));
     pre2_pre1_s2 lca s1 s2;
     assert (common_pre_s2_gt0 lca s1 s2);
     let s2' = inverse_st s2 in
     pre1_pre2_s2 lca s1 s2;
     assert (common_pre_nc lca s1 s2');     
     lem_l2a'' lca s1 s2' last2;
     lem_l2a''_ind lca s1 s2 last2)

let lem_l2a' (lca s1 s2:st)
 : Lemma (requires common_pre_s2_gt0 lca s1 s2 /\ 
                   (let _, last2 = un_snoc (ops_of s2) in
                    Add? (snd last2) /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                    (let s2' = inverse_st s2 in
                    is_prefix (ops_of lca) (ops_of s2'))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let s2' = inverse_st s2 in
                    eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
                       (concrete_merge (v_of lca) (v_of s1) (v_of s2)))) =
   let _, last2 = un_snoc (ops_of s2) in
   let s2' = inverse_st s2 in
   pre1_pre2_s2 lca s1 s2;
   lem_diff (ops_of s2) (ops_of lca); 
   lem_suf_equal2_last (ops_of lca) (ops_of s2); 
   lem_l2a'' lca s1 s2' last2

let lem_l2a (lca s1 s2:st)
  : Lemma (requires common_pre lca s1 s2 /\ 
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     //fst last1 <> fst last2 /\
                     Add? (snd last2) /\
                     //not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                     not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                     //last (resolve_conflict last1 last2) = last2 /\
                     is_prefix (ops_of lca) (ops_of (inverse_st s2))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    eq (do (concrete_merge (v_of lca) (v_of s1) (v_of (inverse_st s2))) last2)
                       (concrete_merge (v_of lca) (v_of s1) (v_of s2)))) =
  lem_l2a' lca s1 s2
 
///////////////////////////////////////////

let lem_exists (lastop:op_t) (l:log)
  : Lemma (requires true) //Rem? (snd lastop))
          (ensures exists_triple lastop l <==> (Rem? (snd lastop) /\
                   (exists op. mem op l /\ Add? (snd op) /\ get_ele op = get_ele lastop /\ fst op <> fst lastop /\
                    (let _, suf = pre_suf l op in
                    (forall r. mem r suf /\ get_ele r = get_ele lastop ==> Add? (snd r))))))
  = ()

(*let lem_exists_last_rem (lastop:log_entry) (l:log)
  : Lemma (requires exists_triple lastop l)
          (ensures Rem? (snd lastop)) = ()*)

let linearizable_gt0_s1'_op (lca s1 s2:st)
  : Lemma (requires common_pre lca s1 s2 /\ 
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     fst last1 <> fst last2 /\
                     exists_triple last1 (diff (ops_of s2) (ops_of lca)) /\
                     (let (_, op2, suf2) = find_triple last1 (diff (ops_of s2) (ops_of lca)) in
                      suf2 = snd (pre_suf (ops_of s2) op2))))
          (ensures (let _, last1 = un_snoc (ops_of s1) in
                    let (pre2, op2, suf2) = find_triple last1 (diff (ops_of s2) (ops_of lca)) in
                    let s2' = inverse_st_op s2 op2 in
                       eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) op2)
                          (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') op2)))) =
  let _, last1 = un_snoc (ops_of s1) in
  let pre2, op2, suf2 = find_triple last1 (diff (ops_of s2) (ops_of lca)) in
  let s2' = inverse_st_op s2 op2 in
  //lem_exists_last_rem last1 (diff (ops_of s2) (ops_of lca));
  lem_exists last1 (diff (ops_of s2) (ops_of lca));
  lem_inverse (ops_of lca) (ops_of s1);
  lem_diff (ops_of s1) (ops_of lca);
  lem_suf_equal2_last (ops_of lca) (ops_of s1);
  lem_diff (ops_of s2) (ops_of lca);
  lem_suf_equal2 (ops_of lca) (ops_of s2) op2;
  lem_inverse_op (ops_of lca) (ops_of s2) op2;
  lem_l2a_l1r_eq'' lca (inverse_st s1) s2' last1 op2

let linearizable_gt0_s2'_op (lca s1 s2:st)
  : Lemma (requires common_pre lca s1 s2 /\ 
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     fst last1 <> fst last2 /\
                     not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                     exists_triple last2 (diff (ops_of s1) (ops_of lca)) /\
                     (let (_, op1, suf1) = find_triple last2 (diff (ops_of s1) (ops_of lca)) in
                      suf1 = snd (pre_suf (ops_of s1) op1))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let (pre1, op1, suf2) = find_triple last2 (diff (ops_of s1) (ops_of lca)) in
                    let s1' = inverse_st_op s1 op1 in
                       eq (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) op1)
                          (concrete_merge (v_of lca) (do (v_of s1') op1) (v_of s2)))) =
  let _, last2 = un_snoc (ops_of s2) in
  let pre1, op1, suf1 = find_triple last2 (diff (ops_of s1) (ops_of lca)) in
  let s1' = inverse_st_op s1 op1 in
  //lem_exists_last_rem last2 (diff (ops_of s1) (ops_of lca));
  lem_exists last2 (diff (ops_of s1) (ops_of lca));
  lem_inverse (ops_of lca) (ops_of s2);
  lem_diff (ops_of s2) (ops_of lca);
  lem_suf_equal2_last (ops_of lca) (ops_of s2);
  lem_diff (ops_of s1) (ops_of lca);
  lem_suf_equal2 (ops_of lca) (ops_of s1) op1;
  lem_inverse_op (ops_of lca) (ops_of s1) op1;
  lem_l1a_l2r_eq'' lca s1' (inverse_st s2) op1 last2

let rem_add_lastop_neq_ele (lca s1 s2:st)
  : Lemma (requires Seq.length (ops_of s1) > Seq.length (ops_of lca) /\
                    common_pre_s2_gt0 lca s1 s2 /\
                    (let _, last2 = un_snoc (ops_of s2) in
                    let _, last1 = un_snoc (ops_of s1) in
                    fst last1 <> fst last2 /\
                    Add? (snd last1) /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                    not (exists_triple last1 (diff (ops_of s2) (ops_of lca)))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let _, last1 = un_snoc (ops_of s1) in
                    ~ (Rem? (snd last2) /\ get_ele last1 = get_ele last2))) =
  let _, last2 = un_snoc (ops_of s2) in
  let _, last1 = un_snoc (ops_of s1) in
  let s1' = inverse_st s1 in
  lemma_mem_snoc (ops_of s1') last1;
  assert (mem last1 (ops_of s1));
  lem_last (ops_of s1);
  assert (last (ops_of s1) = last1);
  lem_diff (ops_of s1) (ops_of lca);
  assert (last (diff (ops_of s1) (ops_of lca)) = last1);
  assert (mem last1 (diff (ops_of s1) (ops_of lca)));
  let pre, suf = pre_suf (diff (ops_of s1) (ops_of lca)) last1 in
  lem_lastop_suf_0 (diff (ops_of s1) (ops_of lca)) pre suf last1;
  assert (length suf = 0);
  lemma_empty suf; 
  comm_empty_log last1 suf; 
  
  assert (Rem? (snd last2) /\ get_ele last1 = get_ele last2 ==> commutative_seq last1 suf); 
  assert (Rem? (snd last2) /\ get_ele last1 = get_ele last2 ==> not (commutative last1 last2));
  assert (Rem? (snd last2) /\ get_ele last1 = get_ele last2 ==> last (resolve_conflict last1 last2) = last1);
  assert (Rem? (snd last2) /\ get_ele last1 = get_ele last2 ==> 
          (not (commutative last1 last2) /\
          last (resolve_conflict last1 last2) = last1 /\
          commutative_seq last1 suf));
  assert (Rem? (snd last2) /\ get_ele last1 = get_ele last2 ==> 
           exists_triple last2 (diff (ops_of s1) (ops_of lca)));
  ()
  
let linearizable_gt0_s1' (lca s1 s2:st)
  : Lemma (requires common_pre lca s1 s2 /\ 
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     fst last1 <> fst last2 /\
                     not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                     not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                     last (resolve_conflict last1 last2) = last1 /\
                     is_prefix (ops_of lca) (ops_of (inverse_st s1))))
          (ensures (let _, last1 = un_snoc (ops_of s1) in
                    eq (do (concrete_merge (v_of lca) (v_of (inverse_st s1)) (v_of s2)) last1)
                       (concrete_merge (v_of lca) (v_of s1) (v_of s2)))) = 
  let _, last1 = un_snoc (ops_of s1) in
  let _, last2 = un_snoc (ops_of s2) in
  resolve_conflict_prop last1 last2;
  assert (Add? (snd last1) /\ Rem? (snd last2) /\ get_ele last1 = get_ele last2);
  if Rem? (snd last1) then ()
    else (assert (Add? (snd last1)); 
          rem_add_lastop_neq_ele lca s1 s2;
          assert (~ (Rem? (snd last2) /\ get_ele last1 = get_ele last2)); ()); 
  assert (~ (Add? (snd last1) /\ Rem? (snd last2) /\ get_ele last1 = get_ele last2)); 
  ()
  
let linearizable_gt0_s2' (lca s1 s2:st)
  : Lemma (requires common_pre lca s1 s2 /\ 
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     fst last1 <> fst last2 /\
                     not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                     not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                     last (resolve_conflict last1 last2) <> last1 /\
                     is_prefix (ops_of lca) (ops_of (inverse_st s2))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    eq (do (concrete_merge (v_of lca) (v_of s1) (v_of (inverse_st s2))) last2)
                       (concrete_merge (v_of lca) (v_of s1) (v_of s2)))) = 
  let _, last1 = un_snoc (ops_of s1) in
  let _, last2 = un_snoc (ops_of s2) in
  resolve_conflict_prop last1 last2;
  assert (last (resolve_conflict last1 last2) = last2);
  if Add? (snd last2) then
    lem_l2a lca s1 s2
  else lem_l2r lca s1 s2


////////////////////////////////////////////////////////////////
//// Sequential implementation //////

// the concrete state 
let concrete_st_s = list nat

// init state 
let init_st_s = []

val filter_seq : f:(nat -> bool)
               -> l:concrete_st_s
               -> Tot (l1:concrete_st_s {(forall e. L.mem e l1 <==> L.mem e l /\ f e)})
let rec filter_seq f l = 
  match l with
  |[] -> []
  |hd::tl -> if f hd then hd::(filter_seq f tl) else filter_seq f tl
  
// apply an operation to a state 
let do_s (st_s:concrete_st_s) (o:op_t) 
  : (r:concrete_st_s{(Add? (snd o) ==> (forall e. L.mem e r <==> L.mem e st_s \/ e = get_ele o)) /\
                     (Rem? (snd o) ==> (forall e. L.mem e r <==> L.mem e st_s /\ e <> get_ele o))}) =
  match snd o with
  |(Add e) -> e::st_s
  |(Rem e) -> filter_seq (fun ele -> ele <> e) st_s

//equivalence relation between the concrete states of sequential type and MRDT
let eq_sm (st_s:concrete_st_s) (st:concrete_st) =
  (forall e. L.mem e st_s <==> mem_ele e st)

//initial states are equivalent
let initial_eq (_:unit)
  : Lemma (ensures eq_sm init_st_s init_st) = ()

//equivalence between states of sequential type and MRDT at every operation
let do_eq (st_s:concrete_st_s) (st:concrete_st) (op:op_t)
  : Lemma (requires eq_sm st_s st)
          (ensures eq_sm (do_s st_s op) (do st op)) = ()

////////////////////////////////////////////////////////////////

(*let rem_add_lastop_neq_ele (lca s1 s2:st)
  : Lemma (requires Seq.length (ops_of s1) > Seq.length (ops_of lca) /\
                    common_pre_s2_gt0 lca s1 s2 /\
                    (let _, last2 = un_snoc (ops_of s2) in
                    let _, last1 = un_snoc (ops_of s1) in
                    Add? (snd last2) /\
                    not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                    not (exists_triple last1 (diff (ops_of s2) (ops_of lca)))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let _, last1 = un_snoc (ops_of s1) in
                    ~ (Rem? (snd last1) /\ get_ele last1 = get_ele last2))) =
  let _, last2 = un_snoc (ops_of s2) in
  let _, last1 = un_snoc (ops_of s1) in
  lastop_neq (ops_of lca) (ops_of s1) (ops_of s2);
  resolve_conflict_prop last1 last2;
  assert (fst last1 <> fst last2);

  let s2' = inverse_st s2 in
  lemma_mem_snoc (ops_of s2') last2;
  assert (mem last2 (ops_of s2));
  lem_last (ops_of s2);
  assert (last (ops_of s2) = last2);
  lem_diff (ops_of s2) (ops_of lca);
  assert (last (diff (ops_of s2) (ops_of lca)) = last2);
  assert (mem last2 (diff (ops_of s2) (ops_of lca)));
  let pre, suf = pre_suf (diff (ops_of s2) (ops_of lca)) last2 in
  lem_lastop_suf_0 (diff (ops_of s2) (ops_of lca)) pre suf last2;
  assert (length suf = 0);
  lemma_empty suf; 
  comm_empty_log last2 suf; 
  
  assert (Rem? (snd last1) /\ get_ele last1 = get_ele last2 ==> commutative_seq last2 suf); 
  assert (Rem? (snd last1) /\ get_ele last1 = get_ele last2 ==> not (commutative last1 last2));
  assert (Rem? (snd last1) /\ get_ele last1 = get_ele last2 ==> last (resolve_conflict last1 last2) = last2);
  assert (Rem? (snd last1) /\ get_ele last1 = get_ele last2 ==> 
          (not (commutative last1 last2) /\
          last (resolve_conflict last1 last2) = last2 /\
          commutative_seq last2 suf));
  assert (Rem? (snd last1) /\ get_ele last1 = get_ele last2 ==> 
           exists_triple last1 (diff (ops_of s2) (ops_of lca)));
  ()*)
         
