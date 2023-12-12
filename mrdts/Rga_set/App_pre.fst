module App_pre

module S = Set_extended

#set-options "--query_stats"
let unique_st (s:S.t (nat & (nat & nat))) =
  forall e. S.mem e s ==> ~ (exists e1. S.mem e1 s /\ snd e <> snd e1 /\ fst e = fst e1)

let mem_id_s (id:nat) (s:S.t (nat & (nat & nat))) =
  exists e. S.mem e s /\ fst e = id

// the concrete state type
type concrete_st = s:(S.t (nat & (nat & nat)) & S.t nat) {unique_st (fst s) /\ (forall id. S.mem id (snd s) ==> mem_id_s id (fst s))}
                   // first ele of the pair is a tuple of timestamp, 
                   //     id after which the ele is to be inserted and ele to be inserted
                   // second ele of the pair is a tombstone set

// init state
let init_st : concrete_st = (S.empty, S.empty)

// equivalence between 2 concrete states
let eq (a b:concrete_st) =
  S.equal (fst a) (fst b) /\
  S.equal (snd a) (snd b)

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
  |Add_after : after_id:nat -> ele:nat -> app_op_t //inserts ele after after_id
  |Remove : id:pos -> app_op_t //removes the element with identifier id

let get_ele (op:op_t{Add_after? (snd (snd op))}) : nat =
  let (_, (_, Add_after _ ele)) = op in ele

let get_after_id (op:op_t{Add_after? (snd (snd op))}) : nat =
  let (_, (_, Add_after id _)) = op in id

let get_rem_id (op:op_t{Remove? (snd (snd op))}) : pos =
  let (_, (_, Remove id)) = op in id

let id_ele (s:concrete_st) (id ele:nat) =
  exists e. S.mem e (fst s) /\ fst e = id /\ snd (snd e) = ele /\ not (S.mem id (snd s))

//pre-condition for do
let do_pre (s:concrete_st) (o:op_t) : prop = 
  match o with
  |(ts, (_, Add_after after_id ele)) -> ~ (mem_id_s ts (fst s)) /\ (~ (after_id = 0) ==> mem_id_s after_id (fst s))
  |(_, (_, Remove id)) -> mem_id_s id (fst s)

// apply an operation to a state
let do (s:concrete_st) (o:op_t{do_pre s o}) : concrete_st =
  match o with
  |(ts, (_, Add_after after_id ele)) -> (S.add (ts, (after_id, ele)) (fst s), snd s)
  |(_, (_, Remove id)) -> (fst s, S.add id (snd s))
  
let rc (o1:op_t) (o2:op_t{distinct_ops o1 o2}) : rc_res = Either

//pre-condition for merge
let merge_pre (l a b:concrete_st) : prop = 
  (forall id. mem_id_s id (fst l) ==> ~ (mem_id_s id (S.difference (fst a) (fst l)))) /\
  (forall id. mem_id_s id (fst l) ==> ~ (mem_id_s id (S.difference (fst b) (fst l)))) /\
  (forall id. mem_id_s id (S.difference (fst a) (fst l)) ==> ~ (mem_id_s id (S.difference (fst b) (fst l))))

// concrete merge operation
let merge (l a:concrete_st) (b:concrete_st{merge_pre l a b}) : concrete_st =
  (S.union (fst l) (S.union (fst a) (fst b)),   
   S.union (snd l) (S.union (snd a) (snd b)))

/////////////////////////////////////////////////////////////////////////////

let no_rc_chain (o1 o2 o3:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ distinct_ops o2 o3)
          (ensures ~ (Fst_then_snd? (rc o1 o2) /\ Fst_then_snd? (rc o2 o3))) = ()

let relaxed_comm (s:concrete_st) (o1 o2 o3:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ distinct_ops o2 o3 /\ Fst_then_snd? (rc o1 o2) /\ ~ (Either? (rc o2 o3)) /\
                    do_pre s o1 /\ do_pre s o2 /\ do_pre (do s o1) o2 /\ do_pre (do s o2) o1 /\
                    do_pre (do (do s o1) o2) o3 /\ do_pre (do (do s o2) o1) o3)
          (ensures eq (do (do (do s o1) o2) o3) (do (do (do s o2) o1) o3)) = ()

#push-options "--ifuel 3"
let non_comm (o1 o2:op_t)
  : Lemma (requires distinct_ops o1 o2)
          (ensures Either? (rc o1 o2) <==> commutes_with o1 o2) = ()

let cond_comm (o1:op_t) (o2:op_t{distinct_ops o1 o2 /\ ~ (Either? (rc o1 o2))}) (o3:op_t) = true

let lem_cond_comm (s:concrete_st) (o1 o2 o3:op_t) (l:log)
  : Lemma (requires distinct_ops o1 o2 /\ ~ (Either? (rc o1 o2)) /\ cond_comm o1 o2 o3 /\
                    do_pre s o1 /\ do_pre s o2 /\ do_pre (do s o1) o2 /\ do_pre (do s o2) o1 /\
                    apply_pre (do (do s o1) o2) l /\ apply_pre (do (do s o2) o1) l /\
                    do_pre (apply_log (do (do s o1) o2) l) o3 /\ do_pre (apply_log (do (do s o2) o1) l) o3)
          (ensures eq (do (apply_log (do (do s o1) o2) l) o3) (do (apply_log (do (do s o2) o1) l) o3)) = ()
          
////////////////////////////////////////////////////////////////////////////

let merge_comm (l a b:concrete_st)
  : Lemma (requires merge_pre l a b /\ merge_pre l b a)
          (ensures (eq (merge l a b) (merge l b a))) = ()
                       
let merge_idem (s:concrete_st)
  : Lemma (requires merge_pre s s s)
          (ensures eq (merge s s s) s) = ()

let fast_fwd_base (a:concrete_st) (op:op_t)
  : Lemma (requires do_pre a op /\ merge_pre a a (do a op))
          (ensures eq (do a op) (merge a a (do a op))) = ()

let fast_fwd_ind1 (a b:concrete_st) (o2 o2':op_t) (l:log)
  : Lemma (requires do_pre b o2 /\ apply_pre a l /\ merge_pre a a (do b o2) /\
                    do b o2 == apply_log a l /\
                    eq (do b o2) (merge a a (do b o2)))
          (ensures do_pre b o2' /\ do_pre (do b o2') o2 /\ merge_pre a a (do (do b o2') o2) ==>
                   eq (do (do b o2') o2) (merge a a (do (do b o2') o2))) = ()

let rc_ind_right1 (l a b:concrete_st) (o1 o2' o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\
                    do_pre a o1 /\ do_pre b o2 /\ merge_pre l (do a o1) (do b o2) /\ merge_pre l (do a o1) b /\
                    do_pre (merge l (do a o1) b) o2 /\
                    eq (merge l (do a o1) (do b o2)) (do (merge l (do a o1) b) o2) /\
                    do_pre b o2' /\ do_pre (do b o2') o2 /\ merge_pre l (do a o1) (do (do b o2') o2) /\
                   merge_pre l (do a o1) (do b o2') /\ do_pre (merge l (do a o1) (do b o2')) o2)
          (ensures eq (merge l (do a o1) (do (do b o2') o2)) (do (merge l (do a o1) (do b o2')) o2)) = ()

let rc_ind_left1 (l a b:concrete_st) (o1 o1' o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\
                    do_pre a o1 /\ do_pre b o2 /\ merge_pre l (do a o1) (do b o2) /\
                    merge_pre l (do a o1) b /\ do_pre (merge l (do a o1) b) o2 /\
                    eq (merge l (do a o1) (do b o2)) (do (merge l (do a o1) b) o2) /\
                    do_pre a o1' /\ do_pre (do a o1') o1 /\ merge_pre l (do (do a o1') o1) (do b o2) /\
                   merge_pre l (do (do a o1') o1) b /\ do_pre (merge l (do (do a o1') o1) b) o2)
          (ensures eq (merge l (do (do a o1') o1) (do b o2)) (do (merge l (do (do a o1') o1) b) o2)) = ()

let comm_ind_right1 (l a b:concrete_st) (o1 o2' o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\ distinct_ops o2' o1 /\
                  ~ (exists o3 a'. do_pre a o1 /\ do_pre a' o3 /\ eq (do a o1) (do a' o3) /\ distinct_ops o2 o3 /\ Fst_then_snd? (rc o2 o3)) /\
                  ~ (exists o3 b'. do_pre b o2 /\ do_pre b' o3 /\ eq (do b o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3)) /\
                  do_pre a o1 /\ do_pre b o2 /\ do_pre b o2' /\ do_pre (do b o2') o2 /\ 
                  merge_pre l (do a o1) (do b o2) /\  merge_pre l (do a o1) (do (do b o2') o2))
       
          (ensures ((merge_pre l (do a o1) b /\ do_pre (merge l (do a o1) b) o2 /\
                    eq (merge l (do a o1) (do b o2)) (do (merge l (do a o1) b) o2)) ==>
                    (merge_pre l (do a o1) (do b o2') /\ do_pre (merge l (do a o1) (do b o2')) o2 /\
                    eq (merge l (do a o1) (do (do b o2') o2)) (do (merge l (do a o1) (do b o2')) o2))) \/
                   
                   ((merge_pre l a (do b o2) /\ do_pre (merge l a (do b o2)) o1 /\
                    eq (merge l (do a o1) (do b o2)) (do (merge l a (do b o2)) o1)) ==>
                    (merge_pre l a (do (do b o2') o2) /\ do_pre (merge l a (do (do b o2') o2)) o1 /\
                    eq (merge l (do a o1) (do (do b o2') o2)) (do (merge l a (do (do b o2') o2)) o1)))) = ()

let comm_ind_left1 (l a b:concrete_st) (o1 o1' o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\ distinct_ops o1' o2 /\
                    ~ (exists o3 a'. do_pre a o1 /\ do_pre a' o3 /\ eq (do a o1) (do a' o3) /\ distinct_ops o2 o3 /\ Fst_then_snd? (rc o2 o3)) /\
                    ~ (exists o3 b'. do_pre b o2 /\ do_pre b' o3 /\ eq (do b o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3)) /\
                    do_pre a o1 /\ do_pre b o2 /\ do_pre a o1' /\ do_pre (do a o1') o1 /\ 
                    merge_pre l (do a o1) (do b o2) /\  merge_pre l (do (do a o1') o1) (do b o2))                  
        
          (ensures ((merge_pre l (do a o1) b /\ do_pre (merge l (do a o1) b) o2 /\
                    eq (merge l (do a o1) (do b o2)) (do (merge l (do a o1) b) o2)) ==>
                    (merge_pre l (do (do a o1') o1) b /\ do_pre (merge l (do (do a o1') o1) b) o2 /\
                    eq (merge l (do (do a o1') o1) (do b o2)) (do (merge l (do (do a o1') o1) b) o2))) \/
                    
                    ((merge_pre l a (do b o2) /\ do_pre (merge l a (do b o2)) o1 /\
                     eq (merge l (do a o1) (do b o2)) (do (merge l a (do b o2)) o1)) ==>
                     (merge_pre l (do a o1') (do b o2) /\ do_pre (merge l (do a o1') (do b o2)) o1 /\
                     eq (merge l (do (do a o1') o1) (do b o2)) (do (merge l (do a o1') (do b o2)) o1)))) = ()

let rc_base1 (l:concrete_st) (o o1 o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\ distinct_ops o o1 /\ distinct_ops o o2 /\
                    do_pre l o1 /\ do_pre l o2 /\ do_pre (do l o1) o2 /\ merge_pre l (do l o1) (do l o2) /\
                    eq (merge l (do l o1) (do l o2)) (do (do l o1) o2))
          (ensures do_pre l o /\ do_pre (do l o) o1 /\ do_pre (do l o) o2 /\ do_pre (do (do l o) o1) o2 /\
                   merge_pre (do l o) (do (do l o) o1) (do (do l o) o2) /\
                   eq (merge (do l o) (do (do l o) o1) (do (do l o) o2)) (do (do (do l o) o1) o2)) = ()
                   
let merge_comm (l a b:st)
  : Lemma (requires cons_reps l a b /\ merge_pre (v_of l) (v_of a) (v_of b))
          (ensures merge_pre (v_of l) (v_of b) (v_of a) /\
                   (eq (merge (v_of l) (v_of a) (v_of b)) 
                       (merge (v_of l) (v_of b) (v_of a)))) = ()
         
let merge_idem (s:st)
  : Lemma (requires merge_pre (v_of s) (v_of s) (v_of s))
          (ensures eq (merge (v_of s) (v_of s) (v_of s)) (v_of s)) = ()

#push-options "--z3rlimit 50 --ifuel 3"
let rec fast_fwd (a b:st)
  : Lemma (requires cons_reps a a b /\ merge_pre (v_of a) (v_of a) (v_of b))
          (ensures S.subset (fst (v_of a)) (fst (v_of b)) /\
                   S.subset (snd (v_of a)) (snd (v_of b)) /\
                   eq (merge (v_of a) (v_of a) (v_of b)) (v_of b)) 
          (decreases length (ops_of b)) =
  if ops_of a = ops_of b then ()
  else 
    (let b' = inverse_st b in
     cons_reps_b' a a b;
     fast_fwd a b')


let lin_prop1 (s:concrete_st) (op1 op2:op_t)
  : Lemma (requires do_pre s op1 /\ do_pre s op2 /\ do_pre (do s op1) op2 /\ do_pre (do s op2) op1)
          (ensures eq (do (do s op1) op2) (do (do s op2) op1)) = ()

let lin_prop3 (l a b:concrete_st) (last2:op_t) 
  :  Lemma (requires do_pre b last2 /\ merge_pre l a b /\ merge_pre l a (do b last2) /\
                     do_pre (merge l a b) last2)
           (ensures eq (do (merge l a b) last2) (merge l a (do b last2))) = ()

let inter_merge1 (l:concrete_st) (o1 o2 o3:op_t)
  : Lemma (requires fst o1 <> fst o3 /\ fst o2 <> fst o3 /\ 
                    do_pre l o1 /\ do_pre l o3 /\ do_pre (do l o1) o2 /\ do_pre (do l o3) o1 /\ do_pre (do (do l o3) o1) o2 /\
                    merge_pre (do l o1) (do (do l o1) o2) (do (do l o3) o1))
          (ensures eq (merge (do l o1) (do (do l o1) o2) (do (do l o3) o1)) (do (do (do l o3) o1) o2)) = ()

let inter_merge2 (l s s':concrete_st) (o1 o2 o3:op_t)
  : Lemma (requires fst o2 <> fst o3 /\ fst o1 <> fst o3 /\
                    do_pre l o3 /\ do_pre l o2 /\ do_pre s' o2 /\ do_pre s o2 /\
                    merge_pre l s (do l o3) /\ merge_pre s (do s o2) s' /\
                    eq (merge l s (do l o3)) s' /\
                    eq (merge s (do s o2) s') (do s' o2) /\
                    do_pre s o1 /\ do_pre s' o1 /\ do_pre (do s o1) o2 /\ do_pre (do s' o1) o2 /\
                    merge_pre (do s o1) (do (do s o1) o2) (do s' o1))
          (ensures eq (merge (do s o1) (do (do s o1) o2) (do s' o1)) (do (do s' o1) o2)) = ()

let inter_merge3 (l a b c:concrete_st) (op op':op_t) 
  : Lemma (requires merge_pre l a b /\ eq (merge l a b) c /\
                    (forall (o:op_t). do_pre b o /\ do_pre c o /\ merge_pre l a (do b o) ==> eq (merge l a (do b o)) (do c o)) /\
                    do_pre b op /\ do_pre c op /\ do_pre (do b op) op' /\ do_pre (do c op) op' /\
                    merge_pre l a (do (do b op) op'))
          (ensures eq (merge l a (do (do b op) op')) (do (do c op) op')) = ()

let inter_merge4 (l s:concrete_st) (o1 o2 o3 o4:op_t)
  : Lemma (requires fst o1 <> fst o3 /\ fst o1 <> fst o4 /\ fst o2 <> fst o3 /\
                    do_pre l o1 /\ do_pre s o3 /\ do_pre (do l o1) o2 /\ do_pre (do s o3) o1 /\ do_pre (do (do s o3) o1) o2 /\
                    merge_pre (do l o1) (do (do l o1) o2) (do (do s o3) o1) /\
                    eq (merge (do l o1) (do (do l o1) o2) (do (do s o3) o1)) (do (do (do s o3) o1) o2) /\
                    do_pre s o4 /\ do_pre (do s o4) o3 /\ do_pre (do (do s o4) o3) o1 /\ do_pre (do (do (do s o4) o3) o1) o2 /\
                    merge_pre (do l o1) (do (do l o1) o2) (do (do (do s o4) o3) o1))
          (ensures eq (merge (do l o1) (do (do l o1) o2) (do (do (do s o4) o3) o1)) 
                      (do (do (do (do s o4) o3) o1) o2)) = ()

////////////////////////////////////////////////////////////////
//// Sequential implementation //////

module L = FStar.List.Tot

let rec mem_id_s_s (id:nat) (l:list (nat * nat)) =
  match l with
  |[] -> false
  |x::xs -> fst x = id || mem_id_s_s id xs

let rec unique_lst (l:list (nat * nat)) =
  match l with
  |[] -> true
  |x::xs -> not (mem_id_s_s (fst x) xs) && unique_lst xs

// the concrete state 
type concrete_st_s = l:list (nat * nat){unique_lst l} //timestamp x element inserted

// init state 
let init_st_s = []

let do_pre_s (s:concrete_st_s) (o:op_t) : prop = 
  match o with
  |(ts, (_, Add_after after_id ele)) -> ~ (mem_id_s_s ts s) /\ (~ (after_id = 0) ==> mem_id_s_s after_id s)
  |(_, (_, Remove id)) -> mem_id_s_s id s

let rec insert (s:concrete_st_s) (ts:nat{not (mem_id_s_s ts s)}) (after_id:nat{~ (after_id = 0) ==> mem_id_s_s after_id s}) (ele:nat) 
  : Tot (r:concrete_st_s{(forall id. mem_id_s_s id s \/ id = ts <==> mem_id_s_s id r) /\ L.mem (ts, ele) r}) (decreases s) =
  match s with
  |[] -> if after_id = 0 then [(ts, ele)] else []
  |x::xs -> if fst x = after_id then x::(ts,ele)::xs else x::insert xs ts after_id ele

let rec remove (s:concrete_st_s) (ts:nat{mem_id_s_s ts s}) : Tot (r:concrete_st_s{forall id. mem_id_s_s id s /\ id <> ts <==> mem_id_s_s id r}) =
  match s with
  |x::xs -> if fst x = ts then xs else x::remove xs ts

// apply an operation to a state 
let do_s1 (s:concrete_st_s) (op:op_t{do_pre_s s op}) : concrete_st_s = 
  match op with
  |(ts, (_, Add_after after_id ele)) -> insert s ts after_id ele
  |(_, (_, Remove id)) -> remove s id

//equivalence relation between the concrete states of sequential type and MRDT
let eq_sm1 (st_s:concrete_st_s) (st:concrete_st) = 
  (forall id. mem_id_s_s id st_s <==> (mem_id_s id (fst st) /\ not (S.mem id (snd st)))) /\
  (forall id ele. id_ele st id ele <==> L.mem (id, ele) st_s)

//initial states are equivalent
let initial_eq1 _
  : Lemma (ensures eq_sm1 init_st_s init_st) = ()

//equivalence between states of sequential type and MRDT at every operation
let do_eq1 (st_s:concrete_st_s) (st:concrete_st) (op:op_t)
  : Lemma (requires eq_sm1 st_s st /\ do_pre st op /\ do_pre_s st_s op)
          (ensures eq_sm1 (do_s1 st_s op) (do st op)) = admit()

////////////////////////////////////////////////////////////////
