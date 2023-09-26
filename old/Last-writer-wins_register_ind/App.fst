module App

open FStar.Seq
open FStar.Ghost
module L = FStar.List.Tot

#set-options "--query_stats"
// the concrete state type
type concrete_st:eqtype = nat * nat

// init state
let init_st = 0, 0

// equivalence between 2 concrete states
let eq (a b:concrete_st) =
  a == b

// few properties of equivalence relation
let symmetric (a b:concrete_st) 
  : Lemma (requires eq a b)
          (ensures eq b a) = ()

let transitive (a b c:concrete_st)
  : Lemma (requires eq a b /\ eq b c)
          (ensures eq a c) = ()

let eq_is_equiv (a b:concrete_st)
  : Lemma (requires a = b)
          (ensures eq a b) = ()

// operation type
type op_t:eqtype = nat

// apply an operation to a state
let do (s:concrete_st) (op:log_entry) : concrete_st = op

(*let do_prop (s:concrete_st) (o:log_entry)
  : Lemma (ensures (forall e. L.mem e (do s o) <==> L.mem e s \/ e = snd o)) = ()*)

let lem_do (a b:concrete_st) (op:log_entry)
   : Lemma (requires eq a b)
           (ensures eq (do a op) (do b op)) = ()
           
////////////////////////////////////////////////////////////////
//// Sequential implementation //////

// the concrete state 
let concrete_st_s = nat

// init state 
let init_st_s = 0

// apply an operation to a state 
let do_s (st_s:concrete_st_s) (op:log_entry) : concrete_st_s = snd op

//equivalence relation between the concrete states of sequential type and MRDT
let eq_sm (st_s:concrete_st_s) (st:concrete_st) =
  st_s == snd st

//initial states are equivalent
let initial_eq (_:unit)
  : Lemma (ensures eq_sm init_st_s init_st) = ()

//equivalence between states of sequential type and MRDT at every operation
let do_eq (st_s:concrete_st_s) (st:concrete_st) (op:log_entry)
  : Lemma (requires eq_sm st_s st)
          (ensures eq_sm (do_s st_s op) (do st op)) = ()

////////////////////////////////////////////////////////////////

//conflict resolution
let resolve_conflict (x:log_entry) (y:log_entry{fst x <> fst y}) 
  : (l:log{Seq.length l = 2}) =
  if lt (fst y) (fst x)
    then cons y (cons x empty)
      else cons x (cons y empty)

let resolve_conflict_prop (x y:log_entry)
  : Lemma (requires fst x <> fst y)
          (ensures (lt (fst y) (fst x) <==> last (resolve_conflict x y) = x) /\
                   (last (resolve_conflict x y) <> x <==> lt (fst x) (fst y)))
  = ()

// concrete merge operation
let concrete_merge (lca s1 s2:concrete_st) : concrete_st =
  (*if lca = s1 then s2
    else if lca = s2 then s1
      else*) if lt (fst s1) (fst s2) then s2 
        else s1

#push-options "--z3rlimit 500"
let linearizable_s1_0_base (lca s1 s2:st)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))))
          (ensures eq (v_of s2) (concrete_merge (v_of lca) (v_of s1) (v_of s2))) = ()
          
let linearizable_s1_0_ind (lca s1 s2:st)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s1 = ops_of lca /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    length (ops_of s2) > length (ops_of lca) /\
                    (let s2' = inverse_st s2 in
                    is_prefix (ops_of lca) (ops_of s2') /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2') (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2') (ops_of lca)))) /\
                    eq (v_of s2') (concrete_merge (v_of lca) (v_of s1) (v_of s2'))))
          (ensures eq (v_of s2) (concrete_merge (v_of lca) (v_of s1) (v_of s2))) = ()

let linearizable_s2_0_base (lca s1 s2:st)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))))
          (ensures eq (v_of s1) (concrete_merge (v_of lca) (v_of s1) (v_of s2))) = ()

let linearizable_s2_0_ind (lca s1 s2:st)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s2 = ops_of lca /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    length (ops_of s1) > length (ops_of lca) /\
                    (let s1' = inverse_st s1 in
                    is_prefix (ops_of lca) (ops_of s1') /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1') (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1') (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    eq (v_of s1') (concrete_merge (v_of lca) (v_of s1') (v_of s2))))
          (ensures eq (v_of s1) (concrete_merge (v_of lca) (v_of s1) (v_of s2))) = ()


////////////////////////

let linearizable_gt0_s2'_base (lca s1 s2:st) (last2:log_entry)
  : Lemma (requires ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    (forall id. mem_id id (ops_of lca) ==> lt id (fst last2)) /\
                    not (mem_id (fst last2) (diff (ops_of s1) (ops_of lca))))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)))) = ()
                       
let linearizable_gt0_s2'_s10_ind (lca s1 s2:st) (last2:log_entry)
  : Lemma (requires ops_of s1 = ops_of lca /\
                    length (ops_of s2) > length (ops_of lca) /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    (forall id. mem_id id (ops_of lca) ==> lt id (fst last2)) /\
                    not (mem_id (fst last2) (diff (ops_of s1) (ops_of lca))) /\
                    
                    (let s2' = inverse_st s2 in
                    is_prefix (ops_of lca) (ops_of s2') /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2') (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2') (ops_of lca)))) /\
                                      
                    (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2)))))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)))) = ()

let linearizable_gt0_s2'_s10_base (lca s1 s2:st) (last2:log_entry)
  : Lemma (requires ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    (forall id. mem_id id (ops_of lca) ==> lt id (fst last2)) /\
                    not (mem_id (fst last2) (diff (ops_of s1) (ops_of lca))))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)))) = ()

let linearizable_gt0_s2'_s1_gt0_ind (lca s1 s2:st) (last2:log_entry)
  : Lemma (requires length (ops_of s1) > length (ops_of lca) /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    (forall id. mem_id id (ops_of lca) ==> lt id (fst last2)) /\
                    not (mem_id (fst last2) (diff (ops_of s1) (ops_of lca))) /\
                    
                    (let s1' = inverse_st s1 in
                    is_prefix (ops_of lca) (ops_of s1') /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1') (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1') (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    not (mem_id (fst last2) (diff (ops_of s1') (ops_of lca))) /\
                    
                    (eq (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) last2)
                        (concrete_merge (v_of lca) (v_of s1') (do (v_of s2) last2)))))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)))) = admit ()

///////////////////////////TRIAL //////////////////
let linearizable_gt0_s2''_base (lca s1 s2:st) (last1 last2: log_entry)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    fst last1 <> fst last2 /\
                    last (resolve_conflict last1 last2) <> last1 /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))))
          (ensures eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = ()
                       
let linearizable_gt0_s2''_s10_base (lca s1 s2:st) (last1 last2: log_entry)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    fst last1 <> fst last2 /\
                    last (resolve_conflict last1 last2) <> last1 /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))))
          (ensures eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = ()

let linearizable_gt0_s2''_s10_s2_gt0 (lca s1 s2:st) (last1 last2: log_entry)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s1 = ops_of lca /\
                    length (ops_of s2) > length (ops_of lca) /\
                    fst last1 <> fst last2 /\
                    last (resolve_conflict last1 last2) <> last1 /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\

                    (let s2' = inverse_st s2 in
                     is_prefix (ops_of lca) (ops_of s2') /\
                     (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2') (ops_of lca)) ==> lt id id1) /\
                     (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2') (ops_of lca)))) /\
                     eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2')) last2)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2))))
          (ensures eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = ()

let linearizable_gt0_s2''_s1_gt0 (lca s1 s2:st) (last1 last2: log_entry)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    Seq.length (ops_of s1) > Seq.length (ops_of lca) /\ 
                  //  Seq.length (ops_of s2) > Seq.length (ops_of lca) /\ 
                    fst last1 <> fst last2 /\
                    last (resolve_conflict last1 last2) <> last1 /\
                   // is_prefix (ops_of lca) (ops_of (inverse_st s2)) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\

                    (let s1' = inverse_st s1 in
                    is_prefix (ops_of lca) (ops_of s1') /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1') (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1') (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    eq (do (concrete_merge (v_of lca) (do (v_of s1') last1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (do (v_of s1') last1) (do (v_of s2) last2))))
          (ensures eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = ()
                       
////////////////////////////
let linearizable_gt0_s1'_base (lca s1 s2:st) (last1:log_entry)
  : Lemma (requires ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    (forall id. mem_id id (ops_of lca) ==> lt id (fst last1)) /\
                    not (mem_id (fst last1) (diff (ops_of s2) (ops_of lca))))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)))) = ()

let linearizable_gt0_s1'_s20_base (lca s1 s2:st) (last1:log_entry)
  : Lemma (requires ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    (forall id. mem_id id (ops_of lca) ==> lt id (fst last1)) /\
                    not (mem_id (fst last1) (diff (ops_of s2) (ops_of lca))))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)))) = ()

let linearizable_gt0_s1'_s20_ind (lca s1 s2:st) (last1:log_entry)
  : Lemma (requires ops_of s2 = ops_of lca /\
                    length (ops_of s1) > length (ops_of lca) /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    (forall id. mem_id id (ops_of lca) ==> lt id (fst last1)) /\
                    not (mem_id (fst last1) (diff (ops_of s2) (ops_of lca))) /\
                    
                    (let s1' = inverse_st s1 in
                    is_prefix (ops_of lca) (ops_of s1') /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1') (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1') (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                                      
                    (eq (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1') last1) (v_of s2)))))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)))) = ()

let linearizable_gt0_s1'_s2_gt0_ind (lca s1 s2:st) (last1:log_entry)
  : Lemma (requires length (ops_of s2) > length (ops_of lca) /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                    (forall id. mem_id id (ops_of lca) ==> lt id (fst last1)) /\
                    not (mem_id (fst last1) (diff (ops_of s2) (ops_of lca))) /\
                    
                    (let s2' = inverse_st s2 in
                    is_prefix (ops_of lca) (ops_of s2') /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2') (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2') (ops_of lca)))) /\
                    not (mem_id (fst last1) (diff (ops_of s2') (ops_of lca))) /\
                    
                    (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2')))))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)))) = admit ()

let linearizable_gt0_s1''_base (lca s1 s2:st) (last1 last2: log_entry)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    fst last1 <> fst last2 /\
                    last (resolve_conflict last1 last2) = last1 /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))))
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = ()

let linearizable_gt0_s1''_s20_base (lca s1 s2:st) (last1 last2: log_entry)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    fst last1 <> fst last2 /\
                    last (resolve_conflict last1 last2) = last1 /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))))
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = ()

let linearizable_gt0_s1''_s20_s1_gt0 (lca s1 s2:st) (last1 last2: log_entry)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s2 = ops_of lca /\
                    length (ops_of s1) > length (ops_of lca) /\
                    fst last1 <> fst last2 /\
                    last (resolve_conflict last1 last2) = last1 /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\

                    (let s1' = inverse_st s1 in
                     is_prefix (ops_of lca) (ops_of s1') /\
                     (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1') (ops_of lca)) ==> lt id id1) /\
                     (forall id. mem_id id (diff (ops_of s1') (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\
                     eq (do (concrete_merge (v_of lca) (v_of s1') (do (v_of s2) last2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1') last1) (do (v_of s2) last2))))
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = ()

let linearizable_gt0_s1''_s2_gt0 (lca s1 s2:st) (last1 last2: log_entry)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    Seq.length (ops_of s2) > Seq.length (ops_of lca) /\ 
                  //  Seq.length (ops_of s2) > Seq.length (ops_of lca) /\ 
                    fst last1 <> fst last2 /\
                    last (resolve_conflict last1 last2) = last1 /\
                   // is_prefix (ops_of lca) (ops_of (inverse_st s2)) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))) /\

                    (let s2' = inverse_st s2 in
                    is_prefix (ops_of lca) (ops_of s2') /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2') (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2') (ops_of lca)))) /\
                    eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2))))
          (ensures eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = ()

////////////////////////////////////////////

(*let linearizable_gt0_inv2'_base (lca s1 s2:st) (last2:log_entry)
  : Lemma (requires ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    not (mem_id (fst last2) (ops_of lca)))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)))) = ()

let linearizable_gt0_inv2'_s10_ind (lca s1 s2:st) (last2:log_entry)
  : Lemma (requires ops_of s1 = ops_of lca /\
                    length (ops_of s2) > length (ops_of lca) /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    not (mem_id (fst last2) (ops_of lca)) /\
                    (let s2' = inverse_st s2 in
                    (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2)))))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)))) = ()

let rec linearizable_gt0_inv2'_s10 (lca s1 s2:st) (last2:log_entry)
  : Lemma (requires ops_of s1 = ops_of lca /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    not (mem_id (fst last2) (ops_of lca)))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2))))
          (decreases length (ops_of s2)) =
  if ops_of s2 = ops_of lca then ()
  else (let s2' = inverse_st s2 in
        linearizable_gt0_inv2'_s10 lca s1 s2' last2;
        linearizable_gt0_inv2'_s10_ind lca s1 s2 last2)

let linearizable_gt0_inv2'_s1_gt0_ind (lca s1 s2:st) (last2:log_entry)
  : Lemma (requires length (ops_of s1) > length (ops_of lca) /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    not (mem_id (fst last2) (ops_of lca)) /\
                    (let s1' = inverse_st s1 in
                    (eq (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) last2)
                       (concrete_merge (v_of lca) (v_of s1') (do (v_of s2) last2)))))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)))) = ()

let rec linearizable_gt0_inv2' (lca s1 s2:st) (last2:log_entry)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    not (mem_id (fst last2) (ops_of lca)))
          (ensures (eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2))))
          (decreases length (ops_of s1)) =
  if ops_of s1 = ops_of lca && ops_of s2 = ops_of lca then
    linearizable_gt0_inv2'_base lca s1 s2 last2
  else if ops_of s1 = ops_of lca then
    linearizable_gt0_inv2'_s10 lca s1 s2 last2
  else (let s1' = inverse_st s1 in
        linearizable_gt0_inv2' lca s1' s2 last2;
        linearizable_gt0_inv2'_s1_gt0_ind lca s1 s2 last2)

let rec mem_ele_id (op:log_entry) (l:log)
  : Lemma (requires mem op l)
          (ensures mem_id (fst op) l) (decreases length l) =
  if head l = op then ()
    else mem_ele_id op (tail l)
    
let lem_suf_equal2_last (lca s1:log)
  : Lemma (requires is_prefix lca s1 /\ length (diff s1 lca) > 0 /\ distinct_ops s1)
          (ensures (let _, lastop = un_snoc s1 in
                    not (mem_id (fst lastop) lca))) =
    distinct_invert_append lca (diff s1 lca); 
    let pre, lst = un_snoc s1 in
    lem_diff s1 lca;
    mem_ele_id lst (diff s1 lca)
    
let linearizable_gt0_inv2 (lca s1 s2:st)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    Seq.length (ops_of s1) > Seq.length (ops_of lca) /\ 
                    Seq.length (ops_of s2) > Seq.length (ops_of lca) /\ 
                    (let _, last1 = un_snoc (ops_of s1) in
                    let _, last2 = un_snoc (ops_of s2) in
                    fst last1 <> fst last2 /\
                    last (resolve_conflict last1 last2) <> last1 /\
                    is_prefix (ops_of lca) (ops_of (inverse_st s2)) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca))))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    eq (do (concrete_merge (v_of lca) (v_of s1) (v_of (inverse_st s2))) last2)
                       (concrete_merge (v_of lca) (v_of s1) (v_of s2)))) = 
  lem_inverse (ops_of lca) (ops_of s2);
  lem_suf_equal2_last (ops_of lca) (ops_of s2); 
  let _, last2 = un_snoc (ops_of s2) in
  linearizable_gt0_inv2' lca s1 (inverse_st s2) last2
                         
let linearizable_gt0 (lca s1 s2:st)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    Seq.length (ops_of s1) > Seq.length (ops_of lca) /\ 
                    Seq.length (ops_of s2) > Seq.length (ops_of lca) /\ 
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     fst last1 <> fst last2 /\
                     (last (resolve_conflict last1 last2) = last1 ==>
                           is_prefix (ops_of lca) (ops_of (inverse_st s1)) /\
                           concrete_merge_pre (v_of lca) (v_of (inverse_st s1)) (v_of s2)) /\
                     (last (resolve_conflict last1 last2) <> last1 ==>
                           is_prefix (ops_of lca) (ops_of (inverse_st s2)) /\
                           concrete_merge_pre (v_of lca) (v_of s1) (v_of (inverse_st s2)))) /\
                    concrete_merge_pre (v_of lca) (v_of s1) (v_of s2) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))))
          (ensures (let _, last1 = un_snoc (ops_of s1) in
                    let _, last2 = un_snoc (ops_of s2) in
                    (last (resolve_conflict last1 last2) = last1 ==>
                      concrete_do_pre (concrete_merge (v_of lca) (v_of (inverse_st s1)) (v_of s2)) last1 /\
                      eq (do (concrete_merge (v_of lca) (v_of (inverse_st s1)) (v_of s2)) last1)
                         (concrete_merge (v_of lca) (v_of s1) (v_of s2))) /\
                    (last (resolve_conflict last1 last2) <> last1 ==>
                      concrete_do_pre (concrete_merge (v_of lca) (v_of s1) (v_of (inverse_st s2))) last2 /\
                      eq (do (concrete_merge (v_of lca) (v_of s1) (v_of (inverse_st s2))) last2)
                         (concrete_merge (v_of lca) (v_of s1) (v_of s2))))) = admit()*)
  
