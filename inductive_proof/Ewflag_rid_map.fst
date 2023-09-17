module Ewflag_rid_map

module M = Map
module S = FStar.Set

#set-options "--query_stats"
let cf = (int * bool)

// the concrete state type
type concrete_st = M.t nat cf // (replica_id, ctr, flag) //replica ids are unique
 
let init_st : concrete_st = M.const (0, false)

let sel (s:concrete_st) k = if M.contains s k then M.sel s k else (0, false)

let eq (a b:concrete_st) =
  (forall id. M.contains a id <==> M.contains b id) /\
  (forall id. sel a id = sel b id)

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
  |Enable 
  |Disable

type timestamp_t = pos 

type op_t = timestamp_t & (nat (*replica_id*) & app_op_t)

let get_rid (_,(rid,_)) = rid

let one_ele k v : concrete_st = M.const_on (Set.singleton k) v

// apply an operation to a state
let do (s:concrete_st) (o:op_t) : concrete_st =
  match o with
  |(_, (rid, Enable)) -> if M.contains s rid then M.upd s rid (fst (sel s rid) + 1, true) 
                        else M.concat (one_ele rid (1, true)) s
  |(_, (rid, Disable)) -> M.map_val (fun (c,f) -> (c, false)) s 

let lem_do (s:concrete_st) (o:op_t)
  : Lemma (requires true) (ensures (let rid = get_rid o in let r:concrete_st = do s o in
                    (Enable? (snd (snd o)) ==> (forall id. M.contains r id <==> M.contains s id \/ id = rid) /\
                      (not (M.contains s rid) ==> sel r rid = (1, true) /\
                        (forall id cf. (sel r id = sel s id) \/ (sel r id = (1, true)))) /\
                      (sel r rid = (fst (sel s rid) + 1, true)) /\
                      (forall id. id <> rid ==> (sel s id = sel r id))) /\
                   (Disable? (snd (snd o)) ==> (forall id. M.contains r id <==> M.contains s id) /\
                     (forall id. sel r id = (fst (sel s id), false)))))
                     [SMTPat (do s o)] = ()

let merge_flag (l a b:cf) : bool =
  let lc = fst l in
  let ac = fst a in
  let bc = fst b in
  let af = snd a in
  let bf = snd b in
    if af && bf then true
      else if not af && not bf then false
        else if af then ac > lc
          else bc > lc

// concrete merge operation
let merge_cf (lca s1 s2:cf) : cf =
  (fst s1 + fst s2 - fst lca, merge_flag lca s1 s2)

let concrete_merge (lca s1 s2:concrete_st) 
  : Tot (r:concrete_st{(forall id. M.contains r id <==> M.contains lca id \/ M.contains s1 id \/ M.contains s2 id) /\
                       (forall id. M.contains r id ==> sel r id = merge_cf (sel lca id) (sel s1 id) (sel s2 id))}) =
  let lca_k = M.domain lca in
  let s1_k = M.domain s1 in
  let s2_k = M.domain s2 in
  let keys = Set.union lca_k (Set.union s1_k s2_k) in
  let u = M.const_on keys (0, false) in
  M.iter_upd (fun k v -> merge_cf (sel lca k) (sel s1 k) (sel s2 k)) u 

let prop1 (l:concrete_st) (o1 o2 o3:op_t)
  : Lemma (requires fst o1 <> fst o3 /\ 
                    ((Enable? (snd (snd o1)) /\ Enable? (snd (snd o3)) /\ Enable? (snd (snd o2))) \/
                     (Enable? (snd (snd o1)) /\ Disable? (snd (snd o3))) \/
                     (Disable? (snd (snd o3)))) /\
                    get_rid o1 = get_rid o2 /\ get_rid o3 <> get_rid o1)
                    //resolve_conflict o1 o3 = First_then_second) //o3.o1
                    //not (resolve_conflict o2 o3 = Second_then_first) //not(o2.o3)
          (ensures eq (concrete_merge (do l o1) (do (do l o1) o2) (do (do l o3) o1)) (do (do (do l o3) o1) o2)) = ()

let prop2 (l s s':concrete_st) (o1 o2 o3:op_t) 
  : Lemma (requires eq (concrete_merge s (do s o2) s') (do s' o2) /\
                    eq (concrete_merge l s (do l o3)) s' /\
                    get_rid o1 = get_rid o2 /\ get_rid o1 <> get_rid o3)
          (ensures eq (concrete_merge (do s o1) (do (do s o1) o2) (do s' o1)) (do (do s' o1) o2)) = ()

let prop3 (s s':concrete_st) (o2 o2':op_t)
  : Lemma (requires eq (concrete_merge s s s') s' /\
                    (forall o. eq (concrete_merge s (do s o) s') (do s' o)) /\
                    fst o2 <> fst o2' /\ get_rid o2 = get_rid o2')
          (ensures eq (concrete_merge s (do (do s o2') o2) s') (do (do s' o2') o2)) = ()

let lem_merge3 (l a b c:concrete_st) (op op':op_t) 
  : Lemma 
    (requires eq (concrete_merge l a b) c /\ 
              fst op <> fst op' /\ get_rid op = get_rid op' /\
              (forall (o:op_t). eq (concrete_merge l a (do b o)) (do c o)))
    (ensures eq (concrete_merge l a (do (do b op) op')) (do (do c op) op')) = ()

let prop4 (l s:concrete_st) (o1 o2 o3 o3':op_t) 
  : Lemma (requires fst o2 <> fst o3 /\ 
                    ((Enable? (snd (snd o1)) /\ Enable? (snd (snd o3))) \/
                     (Disable? (snd (snd o3)))) /\
                    ((Enable? (snd (snd o2)) /\ Enable? (snd (snd o3))) \/
                     (Disable? (snd (snd o3)))) /\
                    ((Enable? (snd (snd o1)) /\ Enable? (snd (snd o3'))) \/
                     (Disable? (snd (snd o3')))) /\
                    ((Enable? (snd (snd o2)) /\ Enable? (snd (snd o3'))) \/
                     (Disable? (snd (snd o3')))) /\
                    get_rid o1 = get_rid o2 /\ get_rid o3 = get_rid o3' /\
                    //o3.o1, o3'.o1, o3.o2, o3'.o2
                    eq (concrete_merge (do l o1) (do (do l o1) o2) (do (do s o3) o1)) (do (do (do s o3) o1) o2))
          (ensures eq (concrete_merge (do l o1) (do (do l o1) o2) (do (do (do s o3') o3) o1)) 
                      (do (do (do (do s o3') o3) o1) o2)) = ()

let lem_merge4 (s s':concrete_st) (op op':op_t)
  : Lemma (requires get_rid op = get_rid op' /\
                    eq (concrete_merge (do s op) (do s' op) (do s op)) (do s' op))
          (ensures eq (concrete_merge (do s op) (do (do s' op') op) (do s op)) (do (do s' op') op)) = ()
          
let idempotence (s:concrete_st)
  : Lemma (eq (concrete_merge s s s) s) = ()

let prop5' (l s s':concrete_st) (o o3:op_t)
  : Lemma (requires eq (concrete_merge s s s') s' /\
                    get_rid o <> get_rid o3 /\ eq (concrete_merge l s (do l o3)) s')
          (ensures eq (concrete_merge s s (do s' o)) (do s' o)) = ()

let prop5 (s s':concrete_st)
  : Lemma (ensures (//eq_id (concrete_merge s s s') s' /\ 
                    eq (concrete_merge s s' s) s')) = 
  admit()
