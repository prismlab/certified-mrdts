module App_new

module S = Set_extended

#set-options "--query_stats"

// the concrete state type
type concrete_st = S.t (nat & (nat & nat)) & S.t nat //fst:(ts,after_id,ele), snd:tombstone set

// init state
let init_st = (S.empty, S.empty)

// equivalence between 2 concrete states
let eq (a b:concrete_st) = 
  S.equal (fst a) (fst b) /\
  S.equal (snd a) (snd b)

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

let mem_id_s (id:nat) (s:S.t (nat & (nat & nat))) =
  exists e. S.mem e s /\ fst e = id
  
// apply an operation to a state
let do (s:concrete_st) (o:op_t) : concrete_st =
  match o with
  |(ts, (_, Add_after after_id ele)) -> (S.add (ts, (after_id, ele)) (fst s), snd s)
  |(_, (_, Remove id)) -> (fst s, S.add id (snd s))

//conflict resolution
let rc (o1 o2:op_t) = Either

// concrete merge operation
let merge (l a b:concrete_st) : concrete_st =
   (S.union (fst l) (S.union (fst a) (fst b)),   
    S.union (snd l) (S.union (snd a) (snd b)))
   
/////////////////////////////////////////////////////////////////////////////
      
let no_rc_chain (o1 o2 o3:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ distinct_ops o2 o3)
          (ensures ~ (Fst_then_snd? (rc o1 o2) /\ Fst_then_snd? (rc o2 o3))) = ()

let relaxed_comm (s:concrete_st) (o1 o2 o3:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ distinct_ops o2 o3 /\ Fst_then_snd? (rc o1 o2) /\ ~ (Either? (rc o2 o3)))
          (ensures eq (do (do (do s o1) o2) o3) (do (do (do s o2) o1) o3)) = ()
   
let non_comm (o1 o2:op_t)
  : Lemma (requires distinct_ops o1 o2)
          (ensures Either? (rc o1 o2) <==> commutes_with o1 o2) = 
  assert ((Add_after? (snd (snd o1)) /\ Add_after? (snd (snd o2))) \/ (Add_after? (snd (snd o1)) /\ Remove? (snd (snd o2))) \/
                   (Remove? (snd (snd o1)) /\ Add_after? (snd (snd o2))) \/ (Remove? (snd (snd o1)) /\ Remove? (snd (snd o2))) ==>
                        (eq (do (do init_st o1) o2) (do (do init_st o2) o1))); ()

let cond_comm (o1:op_t) (o2:op_t{distinct_ops o1 o2 /\ ~ (Either? (rc o1 o2))}) (o3:op_t) = true

let cond_comm_base (s:concrete_st) (o1 o2 o3:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ ~ (Either? (rc o1 o2)) /\ cond_comm o1 o2 o3)
          (ensures eq (do (do (do s o1) o2) o3) (do (do (do s o2) o1) o3)) = ()

let cond_comm_ind (s:concrete_st) (o1 o2 o3 o:op_t) (l:log)
  : Lemma (requires distinct_ops o1 o2 /\ ~ (Either? (rc o1 o2)) /\ cond_comm o1 o2 o3 /\
                    eq (do (apply_log (do (do s o1) o2) l) o3) (do (apply_log (do (do s o2) o1) l) o3))
          (ensures eq (do (do (apply_log (do (do s o1) o2) l) o) o3) (do (do (apply_log (do (do s o2) o1) l) o) o3)) = ()
  
/////////////////////////////////////////////////////////////////////////////
// Merge commutativity
let merge_comm (l a b:concrete_st)
   : Lemma (ensures (eq (merge l a b) (merge l b a))) = ()

// Merge idempotence
let merge_idem (s:concrete_st)
   : Lemma (ensures eq (merge s s s) s) = ()

(*Two OP RC*)
//////////////// 
let rc_ind_right (l a b:concrete_st) (o1 o2' o2:op_t)
   : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\
                     eq (merge l (do a o1) (do b o2)) (do (merge l (do a o1) b) o2))
           (ensures eq (merge l (do a o1) (do (do b o2') o2)) (do (merge l (do a o1) (do b o2')) o2)) = ()

let rc_ind_left (l a b:concrete_st) (o1 o1' o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\
                    eq (merge l (do a o1) (do b o2)) (do (merge l (do a o1) b) o2))
          (ensures eq (merge l (do (do a o1') o1) (do b o2)) (do (merge l (do (do a o1') o1) b) o2)) = ()

//Special case of rc_intermediate_v1
let rc_ind_lca (l:concrete_st) (o o1 o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\ distinct_ops o o1 /\ distinct_ops o o2 /\
                    eq (merge l (do l o1) (do l o2)) (do (do l o1) o2))
          (ensures eq (merge (do l o) (do (do l o) o1) (do (do l o) o2)) (do (do (do l o) o1) o2)) = ()

let rc_base (o1 o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2))
          (ensures eq (merge init_st (do init_st o1) (do init_st o2)) (do (do init_st o1) o2)) = ()

let rc_inter_base_right (l s1 s2 s3:concrete_st) (o o' o1 o2:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\ 
                    distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\
                    eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2) /\
                    eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2) /\
                    eq (merge l (do s1 o') (do s2 o)) (do (do s3 o) o')) //***EXTRA***
          (ensures eq (merge (do l o') (do (do s1 o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do s3 o) o') o1) o2)) = ()

let rc_inter_base_left (l s1 s2 s3:concrete_st) (o o' o1 o2:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\ 
                    distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\
                    eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2) /\
                    eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2) /\
                    eq (merge l (do s1 o) (do s2 o')) (do (do s3 o) o')) //***EXTRA***
          (ensures eq (merge (do l o') (do (do (do s1 o) o') o1) (do (do s2 o') o2)) (do (do (do (do s3 o) o') o1) o2)) = ()
          
(*let rc_intermediate_base_left_right (l s1 s2 s3:concrete_st) (o o' o1' o1 o2:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\  
                    distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\
                    distinct_ops o1' o' /\ Fst_then_snd? (rc o1' o') /\
                    eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2) /\
                    eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2)) 
        (ensures eq (merge (do l o') (do (do (do s1 o1') o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do (do s3 o1') o) o') o1) o2)) = ()*)

let rc_inter_right (l s1 s2 s3:concrete_st) (o1 o2 o o' o_n:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\  
                    distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                    get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                    ((~ (commutes_with o_n o)) \/ Fst_then_snd? (rc o_n o')) /\
                    eq (merge (do l o') (do (do s1 o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do s3 o) o') o1) o2))
      (ensures eq (merge (do l o') (do (do s1 o') o1) (do (do (do (do s2 o_n) o) o') o2)) (do (do (do (do (do s3 o_n) o) o') o1) o2)) = ()

let rc_inter_left (l s1 s2 s3:concrete_st) (o1 o2 o o' o_n:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\  
                    distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                    get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                    ((~ (commutes_with o_n o)) \/ Fst_then_snd? (rc o_n o')) /\
                    eq (merge (do l o') (do (do (do s1 o) o') o1) (do (do s2 o') o2)) (do (do (do (do s3 o) o') o1) o2))
      (ensures eq (merge (do l o') (do (do (do (do s1 o_n) o) o') o1) (do (do s2 o') o2)) (do (do (do (do (do s3 o_n) o) o') o1) o2)) = ()
      
// In general, the events o',o_n, below should be such that these exists o, (rc o o')
let rc_inter_lca (l s1 s2 s3:concrete_st) (o1 o2 o' o_n:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\ 
                    (exists o. Fst_then_snd? (rc o o')) /\ (exists o. Fst_then_snd? (rc o o_n)) /\ 
                    eq (merge (do l o_n) (do (do s1 o_n) o1) (do (do s2 o_n) o2)) (do (do (do s3 o_n) o1) o2) /\
                    eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2))
    (ensures eq (merge (do (do l o_n) o') (do (do (do s1 o_n) o') o1) (do (do (do s2 o_n) o') o2)) (do (do (do (do s3 o_n) o') o1) o2)) = ()

(*One op*)
///////////////
#push-options "--ifuel 3"
let one_op_ind_right (l a b c:concrete_st) (o1 o1':op_t)
   : Lemma (requires eq (merge l a (do b o1)) (do (merge l a b) o1))
           (ensures eq (merge l a (do (do b o1') o1)) (do (merge l a (do b o1')) o1)) = ()
           
let one_op_ind_lca (l:concrete_st) (o o1:op_t)
  : Lemma (requires eq (merge l l (do l o1)) (do l o1))
          (ensures eq (merge (do l o) (do l o) (do (do l o) o1)) (do (do l o) o1) ) = ()

let one_op_base (o1:op_t)
  : Lemma (ensures eq (merge init_st init_st (do init_st o1)) (do init_st o1)) = ()

let one_op_inter_base_right (l s1 s2 s3:concrete_st) (o o' o1:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                    eq (merge (do l o') (do s1 o') (do (do s2 o') o1)) (do (do s3 o') o1) /\
                    eq (merge l s1 (do s2 o1)) (do s3 o1) /\
                    eq (merge l (do s1 o') (do s2 o)) (do (do s3 o) o')) //***EXTRA***
          (ensures eq (merge (do l o') (do s1 o') (do (do (do s2 o) o') o1)) (do (do (do s3 o) o') o1)) = ()

(*let intermediate_base_right_one_op_left (l s1 s2 s3:concrete_st) (o o' o1:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\ distinct_ops o' o1 /\
                    eq (merge (do l o') (do (do s1 o') o1) (do s2 o')) (do (do s3 o') o1) /\
                    (Fst_then_snd? (rc o o1) ==> eq (merge l (do s1 o1) (do s2 o)) (do (merge l s1 (do s2 o)) o1)) /\ //***EXTRA***       
                    eq (merge l (do s1 o1) s2) (do s3 o1) /\
                    eq (merge l (do s1 o') (do s2 o)) (do (do s3 o) o')) //***EXTRA***
          (ensures eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o) o')) (do (do (do s3 o) o') o1)) = ()*)

let one_op_inter_base_left (l s1 s2 s3:concrete_st) (o o' o1:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                    eq (merge (do l o') (do s1 o') (do (do s2 o') o1)) (do (do s3 o') o1) /\
                    (Fst_then_snd? (rc o o1) ==> eq (merge l (do s1 o1) (do s2 o)) (do (merge l s1 (do s2 o)) o1)) /\ //***EXTRA***
                    eq (merge l s1 (do s2 o1)) (do s3 o1) /\
                    eq (merge l (do s1 o') (do s2 o)) (do (do s3 o) o') /\ //***EXTRA***
                    eq (merge l (do (do s1 o) o') (do s2 o')) (do (do s3 o) o')) //***EXTRA***
          (ensures eq (merge (do l o') (do (do s1 o) o') (do (do s2 o') o1)) (do (do (do s3 o) o') o1)) = ()

(*let intermediate_base_left_right_one_op (l s1 s2 s3:concrete_st) (o o' o1' o1:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                    distinct_ops o1' o' /\ Fst_then_snd? (rc o1' o') /\
                    eq (merge (do l o') (do s1 o') (do (do s2 o') o1)) (do (do s3 o') o1) /\
                    eq (merge (do l o') (do (do s1 o1') o') (do (do s2 o') o1)) (do (do (do s3 o1') o') o1) /\ //EXTRA
                    eq (merge l s1 (do s2 o1)) (do s3 o1))
          (ensures eq (merge (do l o') (do (do s1 o1') o') (do (do (do s2 o) o') o1)) (do (do (do (do s3 o1') o) o') o1)) = ()*)

let one_op_inter_left (l s1 s2 s3:concrete_st) (o1 o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                    get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                    eq (merge (do l o') (do (do s1 o) o') (do (do s2 o') o1)) (do (do (do s3 o) o') o1))
          (ensures eq (merge (do l o') (do (do (do s1 o_n) o) o') (do (do s2 o') o1)) (do (do (do (do s3 o_n) o) o') o1)) = ()

// In general, the events o',o_n, below should be such that these exists o, (rc o o')
let one_op_inter_lca (l s1 s2 s3:concrete_st) (o1 o' o_n:op_t)
  : Lemma (requires (exists o. Fst_then_snd? (rc o o')) /\ (exists o. Fst_then_snd? (rc o o_n)) /\ 
                    eq (merge (do l o_n) (do s1 o_n) (do (do s2 o_n) o1)) (do (do s3 o_n) o1) /\
                    eq (merge (do l o') (do s1 o') (do (do s2 o') o1)) (do (do s3 o') o1))
          (ensures eq (merge (do (do l o_n) o') (do (do s1 o_n) o') (do (do (do s2 o_n) o') o1)) (do (do (do s3 o_n) o') o1)) = ()

(*Zero op *)
///////////////
let zero_op_inter_base_right (l s1 s2 s3:concrete_st) (o o':op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                    eq (merge (do l o') (do s1 o') (do s2 o')) (do s3 o') /\
                    eq (merge l s1 s2) s3 /\
                    eq (merge l (do s1 o') (do s2 o)) (do (do s3 o) o')) //***EXTRA***
          (ensures eq (merge (do l o') (do s1 o') (do (do s2 o) o')) (do (do s3 o) o')) = ()

let zero_op_inter_base_left (l s1 s2 s3:concrete_st) (o o' o1':op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\  
                    distinct_ops o1' o' /\ Fst_then_snd? (rc o1' o') /\
                    eq (merge (do l o') (do s1 o') (do s2 o')) (do s3 o') /\
                    eq (merge l s1 s2) s3) 
          (ensures eq (merge (do l o') (do (do s1 o1') o') (do (do s2 o) o')) (do (do (do s3 o1') o) o')) = ()

let zero_op_inter_right (l s1 s2 s3:concrete_st) (o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                    get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                    eq (merge (do l o') (do s1 o') (do (do s2 o) o')) (do (do s3 o) o'))
          (ensures eq (merge (do l o') (do s1 o') (do (do (do s2 o_n) o) o')) (do (do (do s3 o_n) o) o')) = ()

let zero_op_inter_left (l s1 s2 s3:concrete_st) (o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                    get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                    eq (merge (do l o') (do (do s1 o) o') (do s2 o')) (do (do s3 o) o'))
          (ensures eq (merge (do l o') (do (do (do s1 o_n) o) o') (do s2 o')) (do (do (do s3 o_n) o) o')) = ()

// In general, the event "o" below should be such that these exists o', (rc o' o)
let zero_op_inter_lca_v1 (l s1 s2 s3:concrete_st) (o:op_t)
  : Lemma (requires (exists o'. Fst_then_snd? (rc o' o)) /\ eq (merge l s1 s2) s3)
          (ensures eq (merge (do l o) (do s1 o) (do s2 o)) (do s3 o)) = ()

// In general, the events o',o_n, below should be such that these exists o, (rc o o')
let zero_op_inter_lca_v2 (l s1 s2 s3:concrete_st) (o' o_n:op_t)
  : Lemma (requires (exists o. Fst_then_snd? (rc o o')) /\ (exists o. Fst_then_snd? (rc o o_n)) /\ 
                    eq (merge (do l o_n) (do s1 o_n) (do s2 o_n)) (do s3 o_n)  /\
                    eq (merge (do l o') (do s1 o') (do s2 o')) (do s3 o'))
          (ensures eq (merge (do (do l o_n) o') (do (do s1 o_n) o') (do (do s2 o_n) o')) (do (do s3 o_n) o')) = ()

(* 2 op Comm  *)
///////////////////

let comm_ind_right (l a b c:concrete_st) (o1 o2' o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\ distinct_ops o2' o1 /\
                    eq (merge l (do a o1) (do b o2)) (do (do (merge l a b) o2) o1) /\
                    (Fst_then_snd? (rc o2' o1) ==> (eq (merge l (do a o1) (do b o2')) (do (merge l a (do b o2')) o1))) /\
                    ~ (exists o3 a'. eq (do a o1) (do a' o3) /\ distinct_ops o2 o3 /\ Fst_then_snd? (rc o2 o3)) /\
                    ~ (Fst_then_snd? (rc o1 o2')) /\
                    ~ (exists o3 b'. eq (do (do b o2') o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3)) /\
                    ~ (exists o3 b'. eq (do b o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3)))                    
          (ensures eq (merge l (do a o1) (do (do b o2') o2)) (do (do (merge l a (do b o2')) o2) o1)) = ()

let comm_ind_left (l a b c:concrete_st) (o1 o2' o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\ distinct_ops o2' o2 /\
                    eq (merge l (do a o1) (do b o2)) (do (do (merge l a b) o2) o1) /\
                    (Fst_then_snd? (rc o2' o2) ==> (eq (merge l (do a o2') (do b o2)) (do (merge l (do a o2') b) o2))) /\
                    ~ (exists o3 a'. eq (do a o1) (do a' o3) /\ distinct_ops o2 o3 /\ Fst_then_snd? (rc o2 o3)) /\
                    ~ (Fst_then_snd? (rc o2 o2')) /\
                    ~ (exists o3 b'. eq (do (do b o2') o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3)) /\
                    ~ (exists o3 b'. eq (do b o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3)))                    
          (ensures eq (merge l (do (do a o2') o1) (do b o2)) (do (do (merge l (do a o2') b) o2) o1)) = ()

let comm_ind_lca (l:concrete_st) (o o1 o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\ distinct_ops o o1 /\ distinct_ops o o2 /\
                    eq (merge l (do l o1) (do l o2)) (do (do l o2) o1))
          (ensures eq (merge (do l o) (do (do l o) o1) (do (do l o) o2)) (do (do (do l o) o2) o1)) = ()

let comm_base (o1 o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2))
          (ensures eq (merge init_st (do init_st o1) (do init_st o2)) (do (do init_st o1) o2)) = ()

let comm_inter_base_right (l s1 s2 s3:concrete_st) (o o' o1 o2:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\ 
                    distinct_ops o1 o2 /\ Either? (rc o1 o2) /\
                    distinct_ops o' o1 /\ distinct_ops o' o2 /\
                    eq (merge l (do s1 o1) (do (do s2 o) o2)) (do (do (merge l s1 (do s2 o)) o1) o2) /\ //comes from comm_ind_right
                    eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2) /\ 
                    eq (merge (do l o') (do s1 o') (do (do s2 o) o')) (do (do s3 o) o') /\ //comes from intermediate_base_zero_op
                    eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2)) 
          (ensures eq (merge (do l o') (do (do s1 o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do s3 o) o') o1) o2)) = ()

(*let comm_intermediate_base_left_right (l s1 s2 s3:concrete_st) (o o' o1' o1 o2:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\ 
                    distinct_ops o1 o2 /\ Either? (rc o1 o2) /\
                    distinct_ops o1' o' /\ Fst_then_snd? (rc o1' o') /\
                    distinct_ops o' o1 /\ distinct_ops o' o2 /\
                    eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2) /\
                    eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2) /\
                    eq (merge l (do (do s1 o1') o1) (do (do s2 o) o2)) (do (do (merge l (do s1 o1') (do s2 o)) o1) o2) /\ //comes from comm_ind_right
                    eq (merge (do l o') (do s1 o') (do (do s2 o) o')) (do (do s3 o) o')) //comes from intermediate_base_zero_op
        (ensures eq (merge (do l o') (do (do (do s1 o1') o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do (do s3 o1') o) o') o1) o2)) = ()*)

let comm_inter_base_left (l s1 s2 s3:concrete_st) (o o' o1 o2:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\ 
                    distinct_ops o1 o2 /\ Either? (rc o1 o2) /\
                    distinct_ops o' o1 /\ distinct_ops o' o2 /\
                    eq (merge l (do (do s1 o) o1) (do s2 o2)) (do (do (merge l (do s1 o) s2) o1) o2) /\ //comes from comm_ind_left
                    eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2) /\ 
                    eq (merge (do l o') (do (do s1 o) o') (do s2 o')) (do (do s3 o) o') /\ //comes from intermediate_base_zero_op
                    eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2)) 
          (ensures eq (merge (do l o') (do (do (do s1 o) o') o1) (do (do s2 o') o2)) (do (do (do (do s3 o) o') o1) o2)) = ()

let comm_inter_right (l s1 s2 s3:concrete_st) (o1 o2 o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\  
                    distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                    get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                    distinct_ops o_n o' /\ Either? (rc o_n o') /\ 
                    eq (merge (do l o') (do (do s1 o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do s3 o) o') o1) o2))
          (ensures eq (merge (do l o') (do (do s1 o') o1) (do (do (do (do s2 o_n) o) o') o2)) (do (do (do (do (do s3 o_n) o) o') o1) o2)) = ()

let comm_inter_left (l s1 s2 s3:concrete_st) (o1 o2 o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\  
                    distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                    get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                    distinct_ops o_n o' /\ Either? (rc o_n o') /\ 
                    eq (merge (do l o') (do (do (do s1 o) o') o1) (do (do s2 o') o2)) (do (do (do (do s3 o) o') o1) o2))
          (ensures eq (merge (do l o') (do (do (do (do s1 o_n) o) o') o1) (do (do s2 o') o2)) (do (do (do (do (do s3 o_n) o) o') o1) o2)) = ()

let comm_inter_lca (l s1 s2 s3:concrete_st) (o1 o2 o:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\ distinct_ops o1 o /\ distinct_ops o o2 /\
                    (exists o'. Fst_then_snd? (rc o' o)) /\
                    eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2))
          (ensures eq (merge (do l o) (do (do s1 o) o1) (do (do s2 o) o2)) (do (do (do s3 o) o1) o2)) = ()

////////////////////////////////////////////////////////////////
////Equivalence of  MRDT & Sequential implementation  //////

// the concrete state 
let concrete_st_s = S.t (nat & nat)

// init state 
let init_st_s = S.empty

// apply an operation to a state 
let do_s (st_s:concrete_st_s) (o:op_t) = 
match o with
  |(ts, (_, Add_after after_id ele)) -> S.add (fst o, get_ele o) st_s
  |(_, (_, Remove id)) -> S.filter st_s (fun e -> fst e <> id)

// equivalence relation between the concrete states of sequential type and MRDT
let eq_sm (st_s:concrete_st_s) (st:concrete_st) =
  (forall e. S.mem e st_s <==> (exists e1. S.mem e1 (fst st) /\ fst e1 = fst e /\ snd (snd e1) = snd e /\ not (S.mem (fst e1) (snd st))))

// initial states are equivalent
let initial_eq (_:unit)
  : Lemma (ensures eq_sm init_st_s init_st) = ()

//equivalence between states of sequential type and MRDT at every operation
let do_eq1 (st_s:concrete_st_s) (st:concrete_st) (op:op_t)
  : Lemma (requires eq_sm st_s st /\ ~ (S.mem (fst op) (snd st)) /\ ~ (mem_id_s (fst op) (fst st)))
          (ensures eq_sm (do_s st_s op) (do st op)) = ()
         
////////////////////////////////////////////////////////////////
