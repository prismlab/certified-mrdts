module App_user_rc

module S = FStar.Set
module M = Map_extended
module S' = Set_extended_new

#set-options "--query_stats"

let cf = (int * bool)

// the concrete state type
type concrete_st = M.t nat (M.t nat cf) // element ->
                                       //    replica ID -> 
                                       //       (ctr, flag) //elements & replica ids are unique

// init state
let init_st : concrete_st = M.const (M.const (0, false))

let sel_e (s:concrete_st) e = if M.contains s e then M.sel s e else (M.const (0, false))

let sel_id (s:M.t nat cf) id = if M.contains s id then M.sel s id else (0, false)

let ele_id (s:concrete_st) (e id:nat) =
  M.contains s e /\ M.contains (sel_e s e) id
  
// equivalence between 2 concrete states
let eq (a b:concrete_st) =
  (forall e. M.contains a e = M.contains b e) /\
  (forall e. M.contains a e ==> (forall id. M.contains (sel_e a e) id = M.contains (sel_e a e) id /\ sel_id (sel_e a e) id == sel_id (sel_e a e) id))

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
  match snd (snd o) with
  |Add e -> e
  |Rem e -> e
  
// apply an operation to a state
let do (s:concrete_st) (o:op_t) : concrete_st =
 match o with
  |(_, (rid, Add e)) -> M.upd s e (M.upd (sel_e s e) rid (fst (sel_id (sel_e s e) rid) + 1, true))
  |(_, (rid, Rem e)) -> M.iter_upd (fun k v -> if k = get_ele o then ((M.map_val (fun (c,f) -> (c, false))) v) else v) s

#push-options "--ifuel 3"
let lem_do (a b:concrete_st) (op:op_t)
   : Lemma (requires eq a b)
           (ensures eq (do a op) (do b op)) = ()
#pop-options

//operations x and y are commutative
let comm_ops (x y:op_t) : bool =
  match snd (snd x), snd (snd y) with
  |Add x, Rem y -> if x = y then false else true
  |Rem x, Add y -> if x = y then false else true
  |_ -> true

// if x and y are commutative ops, applying them in any order should give equivalent results
let commutative_prop (x y:op_t) 
  : Lemma (requires comm_ops x y)
          (ensures (forall s. eq (apply_log s (cons x (cons y empty))) (apply_log s (cons y (cons x empty))))) = ()

//conflict resolution
let rc (x:op_t) (y:op_t{fst x <> fst y /\ ~ (comm_ops x y)}) : rc_res =
  match snd (snd x), snd (snd y) with
  |Add x, Rem y -> if x = y then Snd_fst else Fst_snd
  |Rem x, Add y -> Fst_snd // Rem x, Add y && x = y

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
let merge_cf (l a b:cf) : cf =
  (fst a + fst b - fst l, merge_flag l a b)
  
// concrete merge operation
let merge_ew (l a b:(M.t nat cf)) : (M.t nat cf) =
  let keys = S.union (M.domain l) (S.union (M.domain a) (M.domain b)) in
  let u = M.const_on keys (0, false) in
  M.iter_upd (fun k v -> merge_cf (sel_id l k) (sel_id a k) (sel_id b k)) u
  
// concrete merge operation
let merge (l a b:concrete_st) : concrete_st =
  let eles = S.union (M.domain l) (S.union (M.domain a) (M.domain b)) in
  let u = M.const_on eles init_st in
  M.iter_upd (fun k v -> merge_ew (sel_e l k) (sel_e a k) (sel_e b k)) u

/////////////////////////////////////////////////////////////////////////////

// Prove that merge is commutative
let merge_comm (l a b:st)
  : Lemma (requires cons_reps l a b)
          (ensures (eq (merge (v_of l) (v_of a) (v_of b)) 
                       (merge (v_of l) (v_of b) (v_of a)))) = ()

let merge_idem (s:st)
  : Lemma (ensures eq (merge (v_of s) (v_of s) (v_of s)) (v_of s)) = ()

#push-options "--z3rlimit 50 --ifuel 3 --split_queries always"
let fast_fwd_base (a b:st) (last2:op_t)
  : Lemma (ensures eq (do (v_of a) last2) (merge (v_of a) (v_of a) (do (v_of a) last2))) = ()

let fast_fwd_ind (a b:st) (last2:op_t)
  : Lemma (requires length (ops_of b) > length (ops_of a) /\
                    (let b' = inverse_st b in
                    cons_reps a a b' /\
                    eq (do (v_of b') last2) (merge (v_of a) (v_of a) (do (v_of b') last2))))
        
          (ensures eq (do (v_of b) last2) (merge (v_of a) (v_of a) (do (v_of b) last2))) = ()
  
let merge_eq (l a b a':concrete_st)
  : Lemma (requires eq a a')
          (ensures eq (merge l a b)
                      (merge l a' b)) = ()

let lin_rc_ind_b' (l a b:st) (last1 last2:op_t)
  : Lemma (requires length (ops_of b) > length (ops_of l) /\
                    fst last1 <> fst last2 /\ ~ (comm_ops last1 last2) /\ Fst_snd? (rc last1 last2) /\
                    (let b' = inverse_st b in
                    eq (do (merge (v_of l) (do (v_of a) last1) (v_of b')) last2)
                       (merge (v_of l) (do (v_of a) last1) (do (v_of b') last2))))
                           
          (ensures eq (do (merge (v_of l) (do (v_of a) last1) (v_of b)) last2)
                      (merge (v_of l) (do (v_of a) last1) (do (v_of b) last2))) = ()

let lin_rc_ind_a' (l a b:st) (last1 last2:op_t)
  : Lemma (requires length (ops_of a) > length (ops_of l) /\
                    fst last1 <> fst last2 /\ ~ (comm_ops last1 last2) /\ Fst_snd? (rc last1 last2) /\
                    (let a' = inverse_st a in
                    eq (do (merge (v_of l) (do (v_of a') last1) (v_of b)) last2)
                       (merge (v_of l) (do (v_of a') last1) (do (v_of b) last2))))
                           
          (ensures eq (do (merge (v_of l) (do (v_of a) last1) (v_of b)) last2)
                      (merge (v_of l) (do (v_of a) last1) (do (v_of b) last2))) = ()

let rec lin_rc (l a b:st) (last1 last2:op_t)
  : Lemma (requires cons_reps l a b /\ 
                    fst last1 <> fst last2 /\ ~ (comm_ops last1 last2) /\ Fst_snd? (rc last1 last2))
          (ensures eq (do (merge (v_of l) (do (v_of a) last1) (v_of b)) last2)
                      (merge (v_of l) (do (v_of a) last1) (do (v_of b) last2)))
          (decreases %[length (ops_of l); length (ops_of a); length (ops_of b)]) =
  if ops_of a = ops_of l && ops_of b = ops_of l then 
    (if length (ops_of l) = 0 then ()
     else 
       (let l' = inverse_st l in
        let _, lastl' = un_snoc (ops_of l) in
        assume (fst lastl' <> fst last2); //can be done
        lin_rc l' l' l' last1 last2; ()))
  else if ops_of a = ops_of l then 
    (let b' = inverse_st b in 
     cons_reps_s2' l a b;
     lin_rc l a b' last1 last2;
     lin_rc_ind_b' l a b last1 last2) 
  else 
    (let a' = inverse_st a in
     cons_reps_s1' l a b;
     lin_rc l a' b last1 last2;
     lin_rc_ind_a' l a b last1 last2)

let comm_empty_log (x:op_t) (l:log)
  : Lemma (ensures length l = 0 ==> commutative_seq x l) = ()
  
let not_add_eq (lca s1:st) (s2:st1)
  : Lemma (requires length (ops_of s1) > length (ops_of lca) /\
                    length (ops_of s2) > length (ops_of lca) /\
                    is_prefix (ops_of lca) (ops_of s1) /\
                    (let _, last2 = un_snoc (ops_of s2) in
                     let _, last1 = un_snoc (ops_of s1) in
                     Rem? (snd (snd last2)) /\
                     fst last1 <> fst last2 /\
                     ~ (reorder last2 (diff (ops_of s1) (ops_of lca)))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let _, last1 = un_snoc (ops_of s1) in
                    ~ (Add? (snd (snd last1)) /\ get_ele last1 = get_ele last2))) = 
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
  assert (commutative_seq last1 suf);

  assert ((Add? (snd (snd last1)) /\ get_ele last1 = get_ele last2) ==> not (comm_ops last2 last1));
  assert ((Add? (snd (snd last1)) /\ get_ele last1 = get_ele last2) ==> Fst_snd? (rc last2 last1)); 
  assert ((Add? (snd (snd last1)) /\ get_ele last1 = get_ele last2) ==> 
                not (comm_ops last2 last1) /\ Fst_snd? (rc last2 last1) /\ commutative_seq last1 suf);
  assert ((Add? (snd (snd last1)) /\ get_ele last1 = get_ele last2) ==> reorder last2 (diff (ops_of s1) (ops_of lca)));
  assert (~ (Add? (snd (snd last1)) /\ get_ele last1 = get_ele last2)); ()

let rec lin_comm1_r (l a b:st) (last1 last2:op_t)
  : Lemma (requires cons_reps l a b /\
                    fst last1 <> fst last2 /\ comm_ops last1 last2 /\ Rem? (snd (snd last2)) /\
                    ~ (reorder last2 (diff (snoc (ops_of a) last1) (ops_of l))))
          (ensures eq (do (merge (v_of l) (do (v_of a) last1) (v_of b)) last2)
                      (merge (v_of l) (do (v_of a) last1) (do (v_of b) last2)))
          (decreases %[length (ops_of b); length (ops_of a)]) = 
  assert (Rem? (snd (snd last1)) \/ (Add? (snd (snd last1)) /\ get_ele last1 <> get_ele last2));
  if ops_of a = ops_of l && ops_of b = ops_of l then ()
  else if ops_of a = ops_of l then ()
  else 
    (let a' = inverse_st a in
     cons_reps_s1' l a b;
     let pre1, last1' = un_snoc (ops_of a) in
     assume (fst last1' <> fst last2); //can be done
     assume (~ (reorder last2 (diff (ops_of a) (ops_of l)))); //can be done
     un_snoc_snoc (ops_of a') last1';
     un_snoc_snoc (ops_of b) last2;
     not_add_eq l (do_st a' last1') (do_st b last2);
     lin_comm1_r l a' b last1' last2)    

let rec lin_comm1_a (l a b:st) (last1 last2:op_t)
  : Lemma (requires cons_reps l a b /\
                    fst last1 <> fst last2 /\ Add? (snd (snd last2)))
          (ensures eq (do (merge (v_of l) (do (v_of a) last1) (v_of b)) last2)
                      (merge (v_of l) (do (v_of a) last1) (do (v_of b) last2)))
          (decreases %[length (ops_of l); length (ops_of a); length (ops_of b)]) = 
  if ops_of a = ops_of l && ops_of b = ops_of l then ()
  else if ops_of b = ops_of l then 
    (let a' = inverse_st a in
     let _, last1' = un_snoc (ops_of a) in
     cons_reps_s1' l a b;
     assume (fst last1' <> fst last2); //can be done
     if Rem? (snd (snd last1)) && get_ele last1 = get_ele last2 then
       lin_comm1_a l a' b last1 last2
     else lin_comm1_a l a' b last1' last2)
  else 
    (let b' = inverse_st b in
     cons_reps_s2' l a b;
     lin_comm1_a l a b' last1 last2)  
#pop-options

let lin_comm (l a b:st) (last1 last2:op_t)
  : Lemma (requires cons_reps l a b /\
                    fst last1 <> fst last2 /\ comm_ops last1 last2 /\
                    ~ (reorder last2 (diff (snoc (ops_of a) last1) (ops_of l))))
          (ensures eq (do (merge (v_of l) (do (v_of a) last1) (v_of b)) last2)
                      (merge (v_of l) (do (v_of a) last1) (do (v_of b) last2))) =
  if Rem? (snd (snd last2)) then lin_comm1_r l a b last1 last2
  else lin_comm1_a l a b last1 last2
                      
let inter_merge1 (l:concrete_st) (o1 o2 o3:op_t)
  : Lemma (requires fst o1 <> fst o3 /\ fst o2 <> fst o3 /\ 
                    ~ (comm_ops o3 o1) /\ ~ (comm_ops o3 o2) /\
                    Fst_snd? (rc o3 o1) /\ Fst_snd? (rc o3 o2))
          (ensures eq (merge (do l o1) (do (do l o1) o2) (do (do l o3) o1)) (do (do (do l o3) o1) o2)) = ()

let inter_merge2 (l s s':concrete_st) (o1 o2 o3:op_t)
  : Lemma (requires fst o2 <> fst o3 /\ fst o1 <> fst o3 /\
                    ~ (comm_ops o3 o1) /\ ~ (comm_ops o3 o2) /\
                    Fst_snd? (rc o3 o1) /\ Fst_snd? (rc o3 o2) /\
                    eq (merge l s (do l o3)) s' /\
                    eq (merge s (do s o2) s') (do s' o2))
          (ensures eq (merge (do s o1) (do (do s o1) o2) (do s' o1)) (do (do s' o1) o2)) = ()

#push-options "--ifuel 3"
let inter_merge3 (l a b c:concrete_st) (op op':op_t) 
  : Lemma (requires eq (merge l a b) c /\
                    (forall (o:op_t). eq (merge l a (do b o)) (do c o)))
          (ensures eq (merge l a (do (do b op) op')) (do (do c op) op')) = ()
#pop-options

let inter_merge4 (l s:concrete_st) (o1 o2 o3 o4:op_t)
  : Lemma (requires fst o1 <> fst o3 /\ fst o1 <> fst o4 /\ fst o2 <> fst o3 /\
                    ~ (comm_ops o3 o1) /\ ~ (comm_ops o3 o2) /\ ~ (comm_ops o4 o1) /\
                    Fst_snd? (rc o3 o1) /\ Fst_snd? (rc o3 o2) /\ Fst_snd? (rc o4 o1) /\
                    eq (merge (do l o1) (do (do l o1) o2) (do (do s o3) o1)) (do (do (do s o3) o1) o2))
          (ensures eq (merge (do l o1) (do (do l o1) o2) (do (do (do s o4) o3) o1)) 
                      (do (do (do (do s o4) o3) o1) o2)) = ()

////////////////////////////////////////////////////////////////
//// Sequential implementation //////

// the concrete state 
let concrete_st_s = S'.t nat

// init state 
let init_st_s = S'.empty

// apply an operation to a state 
let do_s (st_s:concrete_st_s) (o:op_t) : concrete_st_s =
  match o with
  |(ts, (rid, Add e)) -> S'.insert e st_s
  |(_, (rid, Rem e)) -> S'.filter st_s (fun ele -> ele <> e)

// equivalence relation between the concrete states of sequential type and MRDT
let eq_sm (st_s:concrete_st_s) (st:concrete_st) =
  (forall e. S'.mem e st_s <==> (M.contains st e /\ (exists id. snd (sel_id (sel_e st e) id) = true)))

// initial states are equivalent
let initial_eq (_:unit)
  : Lemma (ensures eq_sm init_st_s init_st) = ()
  
// equivalence between states of sequential type and MRDT at every operation
let do_eq (st_s:concrete_st_s) (st:concrete_st) (op:op_t)
  : Lemma (requires eq_sm st_s st)
          (ensures eq_sm (do_s st_s op) (do st op)) = 
  if Add? (snd (snd op)) then 
    (if S'.mem (get_ele op) st_s then () else ()) 
  else ()

////////////////////////////////////////////////////////////////
