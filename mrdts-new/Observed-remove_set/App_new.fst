module App_new

module S = Set_extended

#set-options "--query_stats"

// the concrete state type
type concrete_st = S.t (pos & nat) // (timestamp, ele) //timestamps are unique

// init state
let init_st : concrete_st = S.empty

let mem_id_s (id:pos) (s:concrete_st) : prop =
  exists e. S.mem e s /\ fst e = id

let mem_ele_s (ele:nat) (s:concrete_st) : prop =
  exists e. S.mem e s /\ snd e = ele
  
// equivalence between 2 concrete states
let eq (a b:concrete_st) : Type0 =
  S.equal a b

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

type op_t = pos (*timestamp*) & (nat (*replica ID*) & app_op_t)

let get_rid (_,(rid,_)) = rid

let distinct_ops (op1 op2:op_t) = fst op1 =!= fst op2

type rc_res =
  |Fst_then_snd //o1 -> o2
  |Snd_then_fst //o2 -> o1
  |Either

let get_ele (o:op_t) : nat =
  match snd (snd o) with
  |Add e -> e
  |Rem e -> e

// apply an operation to a state
let do (s:concrete_st) (o:op_t) : concrete_st = 
  match o with
  |(ts, (rid, Add e)) -> S.add (ts, e) s 
  |(_, (rid, Rem e)) -> S.filter s (fun ele -> snd ele <> e)
 
let commutes_with (o1 o2:op_t) =
  forall s. eq (do (do s o1) o2) (do (do s o2) o1)
  
//conflict resolution
let rc (o1:op_t) (o2:op_t{distinct_ops o1 o2}) =  
  match snd (snd o1), snd (snd o2) with
  |Add e1, Rem e2 -> if e1 = e2 then Snd_then_fst else Either
  |Rem e1, Add e2 -> if e1 = e2 then Fst_then_snd else Either
  |_ -> Either
  
// concrete merge operation
let merge (l a b:concrete_st) : concrete_st =
  let da = S.difference a l in    //a - l
  let db = S.difference b l in    //b - l
  let i_ab = S.intersection a b in
  let i_lab = S.intersection l i_ab in   // intersect l a b
  S.union i_lab (S.union da db)          // (intersect l a b) U (a - l) U (b - l)

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
  assert (((Add? (snd (snd o1)) /\ Rem? (snd (snd o2))) \/ (Rem? (snd (snd o1)) /\ Add? (snd (snd o2)))) /\
         get_ele o1 = get_ele o2 ==> ~ (eq (do (do init_st o1) o2) (do (do init_st o2) o1))); ()
         
let cond_comm (o1:op_t) (o2:op_t{distinct_ops o1 o2 /\ ~ (Either? (rc o1 o2))}) (o3:op_t)=
  if Rem? (snd (snd o3)) && get_ele o1 = get_ele o3 then true else false

//#push-options "--z3rlimit 50 --max_ifuel 3 --split_queries on_failure"
#push-options "--z3rlimit 50 --max_ifuel 3"

// let cond_comm_base (s:concrete_st) (o1 o2 o3:op_t)
//   : Lemma (requires distinct_ops o1 o2 /\ ~ (Either? (rc o1 o2)) /\ cond_comm o1 o2 o3)
//           (ensures eq (do (do (do s o1) o2) o3) (do (do (do s o2) o1) o3)) = ()

// let cond_comm_ind (s:concrete_st) (o1 o2 o3 o:op_t) (l:log)
//   : Lemma (requires distinct_ops o1 o2 /\ ~ (Either? (rc o1 o2)) /\ cond_comm o1 o2 o3 /\
//                     eq (do (apply_log (do (do s o1) o2) l) o3) (do (apply_log (do (do s o2) o1) l) o3))
//           (ensures eq (do (do (apply_log (do (do s o1) o2) l) o) o3) (do (do (apply_log (do (do s o2) o1) l) o) o3)) = ()
  
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
let rc_base (l:concrete_st) (o o1 o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\ distinct_ops o o1 /\ distinct_ops o o2 /\
                    eq (merge l (do l o1) (do l o2)) (do (do l o1) o2))
          (ensures eq (merge (do l o) (do (do l o) o1) (do (do l o) o2)) (do (do (do l o) o1) o2)) = ()

let rc_base_base (o1 o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2))
          (ensures eq (merge init_st (do init_st o1) (do init_st o2)) (do (do init_st o1) o2)) = ()

let rc_intermediate_base_right (l s1 s2 s3:concrete_st) (o o' o1 o2:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o')  
                    /\ distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\ distinct_ops o' o2
                    /\ eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2)
                    /\ eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2)
                    /\ eq (merge l (do s1 o') (do s2 o)) (do (do s3 o) o')) //***EXTRA***
          (ensures eq (merge (do l o') (do (do s1 o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do s3 o) o') o1) o2)) = ()
          
let rc_intermediate_base_left_right (l s1 s2 s3:concrete_st) (o o' o1' o1 o2:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o')  
                    /\ distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2)
                    /\ distinct_ops o1' o' /\ Fst_then_snd? (rc o1' o')
                    /\ eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2)
                    /\ eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2)) 
        (ensures eq (merge (do l o') (do (do (do s1 o1') o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do (do s3 o1') o) o') o1) o2)) = ()

let rc_intermediate_2_right (l s1 s2 s3:concrete_st) (o1 o2:op_t) (o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
: Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\  
                  distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                  get_rid o <> get_rid o' (*o,o' must be concurrent *) /\
                  get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                  eq (merge (do l o') (do (do s1 o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do s3 o) o') o1) o2))
      (ensures eq (merge (do l o') (do (do s1 o') o1) (do (do (do (do s2 o_n) o) o') o2)) (do (do (do (do (do s3 o_n) o) o') o1) o2)) = ()

let rc_intermediate_2_left (l s1 s2 s3:concrete_st) (o1 o2:op_t) (o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
: Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\  
                  distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                  get_rid o <> get_rid o' (*o,o' must be concurrent *) /\
                  get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                  eq (merge (do l o') (do (do (do s1 o) o') o1) (do (do s2 o') o2)) (do (do (do (do s3 o) o') o1) o2))
      (ensures eq (merge (do l o') (do (do (do (do s1 o_n) o) o') o1) (do (do s2 o') o2)) (do (do (do (do (do s3 o_n) o) o') o1) o2)) = ()

// In general, the event "o" below should be such that these exists o', (rc o' o)
let rc_intermediate_1_v1 (l s1 s2 s3:concrete_st) (o1 o2: op_t) (o:op_t{Add? (snd (snd o))})
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\ distinct_ops o1 o /\ distinct_ops o o2 /\
                    eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2))
          (ensures eq (merge (do l o) (do (do s1 o) o1) (do (do s2 o) o2)) (do (do (do s3 o) o1) o2)) = ()

// In general, the events o',o_n, below should be such that these exists o, (rc o o')
let rc_intermediate_1_v2 (l s1 s2 s3:concrete_st) (o1 o2:op_t) (o':op_t{Add? (snd (snd o'))}) (o_n:op_t{Add? (snd (snd o_n))})
  : Lemma (requires distinct_ops o1 o2 /\ Fst_then_snd? (rc o1 o2) /\ 
                    get_rid o1 <> get_rid o2 /\
                    eq (merge (do l o_n) (do (do s1 o_n) o1) (do (do s2 o_n) o2)) (do (do (do s3 o_n) o1) o2) /\
                    eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2))
    (ensures eq (merge (do (do l o_n) o') (do (do (do s1 o_n) o') o1) (do (do (do s2 o_n) o') o2)) (do (do (do (do s3 o_n) o') o1) o2)) = ()

(*One op*)
///////////////
let ind_right_one_op (l a b c:concrete_st) (o1 o1':op_t)
   : Lemma (requires eq (merge l a (do b o1)) (do (merge l a b) o1))
           (ensures eq (merge l a (do (do b o1') o1)) (do (merge l a (do b o1')) o1)) = ()
           
let base_one_op (l:concrete_st) (o o1:op_t)
  : Lemma (requires eq (merge l l (do l o1)) (do l o1))
          (ensures eq (merge (do l o) (do l o) (do (do l o) o1)) (do (do l o) o1) ) = ()

let base_base_one_op (o1:op_t)
  : Lemma (ensures eq (merge init_st init_st (do init_st o1)) (do init_st o1)) = ()

//counter-example -> l={}, s1={(1,1)}, s2={}, s3==s1, o1=Rem(2), o'=(2,(_,Add(1))), o=Rem(1)
let intermediate_base_right_one_op_right (l s1 s2 s3:concrete_st) (o o' o1:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\ distinct_ops o' o1
                    /\ eq (merge (do l o') (do s1 o') (do (do s2 o') o1)) (do (do s3 o') o1)
                    /\ eq (merge l s1 (do s2 o1)) (do s3 o1)
                    /\ eq (merge l (do s1 o') (do s2 o)) (do (do s3 o) o')) //***EXTRA***
          (ensures eq (merge (do l o') (do s1 o') (do (do (do s2 o) o') o1)) (do (do (do s3 o) o') o1)) = ()

let intermediate_base_right_one_op_left (l s1 s2 s3:concrete_st) (o o' o1:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\ distinct_ops o' o1
                    /\ eq (merge (do l o') (do (do s1 o') o1) (do s2 o')) (do (do s3 o') o1)
                    /\ eq (merge l (do s1 o1) s2) (do s3 o1)
                    /\ eq (merge (do l o') (do (do l o') o1) (do (do l o) o')) (do (do (do l o) o') o1) //**EXTRA***
                    /\ eq (merge l (do s1 o') (do s2 o)) (do (do s3 o) o')) //***EXTRA***
          (ensures eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o) o')) (do (do (do s3 o) o') o1)) = ()

let intermediate_base_left_right_one_op_right (l s1 s2 s3:concrete_st) (o o' o1' o1:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o')  
                    /\ distinct_ops o1' o' /\ Fst_then_snd? (rc o1' o')
                    /\ eq (merge (do l o') (do s1 o') (do (do s2 o') o1)) (do (do s3 o') o1)
                    /\ eq (merge l s1 (do s2 o1)) (do s3 o1)
                    /\ eq (merge (do l o') (do (do l o') o1) (do (do l o) o')) (do (do (do l o) o') o1)) //***EXTRA***
          (ensures eq (merge (do l o') (do (do s1 o1') o') (do (do (do s2 o) o') o1)) (do (do (do (do s3 o1') o) o') o1)) = ()

let intermediate_base_left_right_one_op_left (l s1 s2 s3:concrete_st) (o o' o1' o1:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o')  
                    /\ distinct_ops o1' o' /\ Fst_then_snd? (rc o1' o')
                    /\ eq (merge (do l o') (do (do s1 o') o1) (do s2 o')) (do (do s3 o') o1)
                    /\ eq (merge l (do s1 o1) s2) (do s3 o1)
                    /\ eq (merge (do l o') (do (do l o') o1) (do (do l o) o')) (do (do (do l o) o') o1)) //***EXTRA***
          (ensures eq (merge (do l o') (do (do (do s1 o1') o') o1) (do (do s2 o) o')) (do (do (do (do s3 o1') o) o') o1)) = ()
          
let intermediate_2_right_one_op (l s1 s2 s3:concrete_st) (o1: op_t) (o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
: Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                  get_rid o <> get_rid o' (*o,o' must be concurrent *) /\
                  get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                  eq (merge (do l o') (do s1 o') (do (do (do s2 o) o') o1)) (do (do (do s3 o) o') o1))
      (ensures eq (merge (do l o') (do s1 o') (do (do (do (do s2 o_n) o) o') o1)) (do (do (do (do s3 o_n) o) o') o1)) = ()

let intermediate_2_left_one_op (l s1 s2 s3:concrete_st) (o1:op_t) (o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
: Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                  get_rid o <> get_rid o' (*o,o' must be concurrent *) /\
                  get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                  eq (merge (do l o') (do (do s1 o) o') (do (do s2 o') o1)) (do (do (do s3 o) o') o1))
      (ensures eq (merge (do l o') (do (do (do s1 o_n) o) o') (do (do s2 o') o1)) (do (do (do (do s3 o_n) o) o') o1)) = ()

// In general, the event "o" below should be such that these exists o', (rc o' o)
let intermediate_1_v1_one_op (l s1 s2 s3:concrete_st) (o1: op_t) (o:op_t{Add? (snd (snd o))})
  : Lemma (requires distinct_ops o1 o /\
                    eq (merge l s1 (do s2 o1)) (do s3 o1))
          (ensures eq (merge (do l o) (do s1 o) (do (do s2 o) o1)) (do (do s3 o) o1)) = ()

                   //(OR)//
                   
// In general, the events o',o_n, below should be such that these exists o, (rc o o')
let intermediate_1_v2_one_op (l s1 s2 s3:concrete_st) (o1:op_t) (o':op_t{Add? (snd (snd o'))}) (o_n:op_t{Add? (snd (snd o_n))})
  : Lemma (requires eq (merge (do l o_n) (do s1 o_n) (do (do s2 o_n) o1)) (do (do s3 o_n) o1) /\
                    eq (merge (do l o') (do s1 o') (do (do s2 o') o1)) (do (do s3 o') o1))
          (ensures eq (merge (do (do l o_n) o') (do (do s1 o_n) o') (do (do (do s2 o_n) o') o1)) (do (do (do s3 o_n) o') o1)) = ()

(*Zero op *)
///////////////
let intermediate_base_right_zero_op (l s1 s2 s3:concrete_st) (o o':op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o')  
                    /\ eq (merge (do l o') (do s1 o') (do s2 o')) (do s3 o')
                    /\ eq (merge l s1 s2) s3
                    /\ eq (merge l (do s1 o') (do s2 o)) (do (do s3 o) o')) //***EXTRA***
          (ensures eq (merge (do l o') (do s1 o') (do (do s2 o) o')) (do (do s3 o) o')) = ()

let intermediate_base_left_right_zero_op (l s1 s2 s3:concrete_st) (o o' o1':op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o')  
                    /\ distinct_ops o1' o' /\ Fst_then_snd? (rc o1' o')
                    /\ eq (merge (do l o') (do s1 o') (do s2 o')) (do s3 o')
                    /\ eq (merge l s1 s2) s3 ) 
          (ensures eq (merge (do l o') (do (do s1 o1') o') (do (do s2 o) o')) (do (do (do s3 o1') o) o')) = ()

let intermediate_2_right_zero_op (l s1 s2 s3:concrete_st) (o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
: Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                  get_rid o <> get_rid o' (*o,o' must be concurrent *) /\
                  get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                  eq (merge (do l o') (do s1 o') (do (do s2 o) o')) (do (do s3 o) o'))
      (ensures eq (merge (do l o') (do s1 o') (do (do (do s2 o_n) o) o')) (do (do (do s3 o_n) o) o')) = ()

let intermediate_2_left_zero_op (l s1 s2 s3:concrete_st) (o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
: Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                  get_rid o <> get_rid o' (*o,o' must be concurrent *) /\
                  get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                  eq (merge (do l o') (do (do s1 o) o') (do s2 o')) (do (do s3 o) o'))
      (ensures eq (merge (do l o') (do (do (do s1 o_n) o) o') (do s2 o')) (do (do (do s3 o_n) o) o')) = ()

// In general, the event "o" below should be such that these exists o', (rc o' o)
let intermediate_1_v1_zero_op (l s1 s2 s3:concrete_st) (o:op_t{Add? (snd (snd o))})
  : Lemma (requires eq (merge l s1 s2) s3)
          (ensures eq (merge (do l o) (do s1 o) (do s2 o)) (do s3 o) ) = ()

// In general, the events o',o_n, below should be such that these exists o, (rc o o')
let intermediate_1_v2_zero_op (l s1 s2 s3:concrete_st) (o':op_t{Add? (snd (snd o'))}) (o_n:op_t{Add? (snd (snd o_n))})
  : Lemma (requires eq (merge (do l o_n) (do s1 o_n) (do s2 o_n)) (do s3 o_n)  /\
                    eq (merge (do l o') (do s1 o') (do s2 o')) (do s3 o'))
          (ensures eq (merge (do (do l o_n) o') (do (do s1 o_n) o') (do (do s2 o_n) o')) (do (do s3 o_n) o')) = ()

(* 2 op Comm  *)
///////////////////

let comm_ind_right (l a b c:concrete_st) (o1 o2' o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\ distinct_ops o2' o1 /\
                    //commutes_with o1 o2 /\
                    eq (merge l (do a o1) (do b o2)) (do (do (merge l a b) o2) o1) /\
                    (Fst_then_snd? (rc o2' o1) ==> (eq (merge l (do a o1) (do b o2')) (do (merge l a (do b o2')) o1))) /\
                    ~ (exists o3 a'. eq (do a o1) (do a' o3) /\ distinct_ops o2 o3 /\ Fst_then_snd? (rc o2 o3)) /\
                    ~ (Fst_then_snd? (rc o1 o2')) /\
                    ~ (exists o3 b'. eq (do (do b o2') o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3)) /\
                    ~ (exists o3 b'. eq (do b o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3)))                    
          (ensures eq (merge l (do a o1) (do (do b o2') o2)) (do (do (merge l a (do b o2')) o2) o1)) = ()

let comm_ind_left (l a b c:concrete_st) (o1 o2' o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\ distinct_ops o2' o2 /\
                    //commutes_with o1 o2 /\
                    eq (merge l (do a o1) (do b o2)) (do (do (merge l a b) o2) o1) /\
                    (Fst_then_snd? (rc o2' o2) ==> (eq (merge l (do a o2') (do b o2)) (do (merge l (do a o2') b) o2))) /\
                    ~ (exists o3 a'. eq (do a o1) (do a' o3) /\ distinct_ops o2 o3 /\ Fst_then_snd? (rc o2 o3)) /\
                    ~ (Fst_then_snd? (rc o2 o2')) /\
                    ~ (exists o3 b'. eq (do (do b o2') o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3)) /\
                    ~ (exists o3 b'. eq (do b o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3)))                    
          (ensures eq (merge l (do (do a o2') o1) (do b o2)) (do (do (merge l (do a o2') b) o2) o1)) = ()

let comm_base (l:concrete_st) (o o1 o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\ distinct_ops o o1 /\ distinct_ops o o2 /\
                    // commutes_with o1 o2 /\
                    eq (merge l (do l o1) (do l o2)) (do (do l o2) o1))
          (ensures eq (merge (do l o) (do (do l o) o1) (do (do l o) o2)) (do (do (do l o) o2) o1)) = ()

let comm_base_base (o1 o2:op_t)
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2))
          (ensures eq (merge init_st (do init_st o1) (do init_st o2)) (do (do init_st o1) o2)) = ()

let comm_intermediate_base_right (l s1 s2 s3:concrete_st) (o o' o1 o2:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o')  
                    /\ distinct_ops o1 o2 /\ Either? (rc o1 o2)
                    /\ distinct_ops o' o1 /\ distinct_ops o' o2
                    // /\ ~ (exists o3 a'. eq (do s1 o1) (do a' o3) /\ distinct_ops o2 o3 /\ Fst_then_snd? (rc o2 o3)) 
                    // /\ ~ (exists o3 b'. eq (do s2 o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3)) 
                    // /\ ~ (exists o3 a'. eq (do (do s1 o') o1) (do a' o3) /\ distinct_ops o2 o3 /\ Fst_then_snd? (rc o2 o3)) 
                    // /\ ~ (exists o3 b'. eq (do (do s2 o') o2) (do b' o3) /\ distinct_ops o1 o3 /\ Fst_then_snd? (rc o1 o3))
                    /\ eq (merge l (do s1 o1) (do (do s2 o) o2)) (do (do (merge l s1 (do s2 o)) o1) o2) //comes from comm_ind_right
                    /\ eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2) 
                    /\ eq (merge (do l o') (do s1 o') (do (do s2 o) o')) (do (do s3 o) o') //comes from intermediate_base_zero_op
                    /\ eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2) ) 
          (ensures eq (merge (do l o') (do (do s1 o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do s3 o) o') o1) o2)) = ()
        //  //if Rem? (snd (snd o1)) && Rem? (snd (snd o2)) then ()
        //           // if Add? (snd (snd o1)) && Rem? (snd (snd o2))  then ()
        //           //  if Rem? (snd (snd o1)) && Add? (snd (snd o2))  then ()
        //             if Add? (snd (snd o1)) && Add? (snd (snd o2)) then ()
        //              else admit()

let comm_intermediate_base_left_right (l s1 s2 s3:concrete_st) (o o' o1' o1 o2:op_t) 
  : Lemma (requires distinct_ops o o' /\ Fst_then_snd? (rc o o')  
                    /\ distinct_ops o1 o2 /\ Either? (rc o1 o2)
                    /\ distinct_ops o1' o' /\ Fst_then_snd? (rc o1' o')
                    /\ distinct_ops o' o1 /\ distinct_ops o' o2
                    /\ eq (merge (do l o') (do (do s1 o') o1) (do (do s2 o') o2)) (do (do (do s3 o') o1) o2)
                    /\ eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2)  
                    /\ eq (merge l (do (do s1 o1') o1) (do (do s2 o) o2)) (do (do (merge l (do s1 o1') (do s2 o)) o1) o2) //comes from comm_ind_right
                    /\ eq (merge (do l o') (do s1 o') (do (do s2 o) o')) (do (do s3 o) o')) //comes from intermediate_base_zero_op

        (ensures eq (merge (do l o') (do (do (do s1 o1') o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do (do s3 o1') o) o') o1) o2)) = ()

let comm_intermediate_2_right (l s1 s2 s3:concrete_st) (o1 o2:op_t) (o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
: Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\  
                  distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                  get_rid o <> get_rid o' (*o,o' must be concurrent *) /\
                  get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                  eq (merge (do l o') (do (do s1 o') o1) (do (do (do s2 o) o') o2)) (do (do (do (do s3 o) o') o1) o2))
      (ensures eq (merge (do l o') (do (do s1 o') o1) (do (do (do (do s2 o_n) o) o') o2)) (do (do (do (do (do s3 o_n) o) o') o1) o2)) = ()

let comm_intermediate_2_left (l s1 s2 s3:concrete_st) (o1 o2:op_t) (o o':op_t) (o_n:op_t{~ (commutes_with o_n o)})
: Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\  
                  distinct_ops o o' /\ Fst_then_snd? (rc o o') /\
                  get_rid o <> get_rid o' (*o,o' must be concurrent *) /\
                  get_rid o_n <> get_rid o' (*o_n,o' must be concurrent*) /\
                  eq (merge (do l o') (do (do (do s1 o) o') o1) (do (do s2 o') o2)) (do (do (do (do s3 o) o') o1) o2))
      (ensures eq (merge (do l o') (do (do (do (do s1 o_n) o) o') o1) (do (do s2 o') o2)) (do (do (do (do (do s3 o_n) o) o') o1) o2)) = ()

let comm_intermediate_1_v1 (l s1 s2 s3:concrete_st) (o1 o2:op_t) (o:op_t{Add? (snd (snd o))})
  : Lemma (requires distinct_ops o1 o2 /\ Either? (rc o1 o2) /\ distinct_ops o1 o /\ distinct_ops o o2 /\
                    eq (merge l (do s1 o1) (do s2 o2)) (do (do s3 o1) o2))
          (ensures eq (merge (do l o) (do (do s1 o) o1) (do (do s2 o) o2)) (do (do (do s3 o) o1) o2)) = ()
